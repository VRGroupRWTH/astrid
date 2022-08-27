#include <astrid/client.hpp>

#include <condition_variable>
#include <mutex>
#include <stdexcept>

namespace ast
{
client::client (
  const std::function<void(proto::request&)>&     on_request ,
  const std::function<void(const proto::image&)>& on_response,
  const std::function<void()>&                    on_finalize,
  const std::string&                              address    , 
  const std::int32_t                              timeout_ms )
: on_request_(on_request), on_response_(on_response), on_finalize_(on_finalize)
{
  zmq::monitor_t monitor;
  monitor.init   (socket_, "inproc://monitor", ZMQ_EVENT_CONNECTED);
  socket_.connect("tcp://" + address);
  if (!monitor.check_event(timeout_ms))
    throw std::runtime_error("Server unreachable.");

  connect(this, &client::on_request_internal , this, [&]
  {
    if (on_request_)
      on_request_(request_data_);
    request_cv_.notify_all();
  });
  connect(this, &client::on_response_internal, this, [&]
  {
    if (on_response_)
      on_response_(response_data_);
    response_cv_.notify_all();
  });
  connect(this, &client::on_finalize_internal, this, [&]
  {
    if (on_finalize_)
      on_finalize_();
  });

  future_ = std::async(std::launch::async, [&]
  {
    while (alive_)
    {
      if (request_auto_ || request_once_)
      {
        if (request_once_)
          request_once_ = false;

        std::unique_lock request_lock(request_mutex_);
        emit on_request_internal();
        request_cv_.wait(request_lock);

        auto string = request_data_.SerializeAsString();

        zmq::message_t message(string.data(), string.size());
        socket_ .send   (message);
        message.rebuild();
        socket_ .recv   (message);

        response_data_.ParseFromArray(message.data(), static_cast<std::int32_t>(message.size()));

        std::unique_lock response_lock(response_mutex_);
        emit on_response_internal();
        response_cv_.wait(response_lock);
      }
    }

    emit on_finalize_internal();
  });
}
client::~client()
{
  alive_ = false;
  future_.get();
}
}