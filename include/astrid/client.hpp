#pragma once

#include <atomic>
#include <cstdint>
#include <functional>
#include <future>
#include <string>

#include <QObject>
#include <zmq.hpp>

#include <request.pb.h>
#include <image.pb.h>

namespace ast
{
class client : public QObject
{
  Q_OBJECT

public:
  explicit client  (
    const std::function<void(proto::request&)>&     on_request ,
    const std::function<void(const proto::image&)>& on_response,
    const std::function<void()>&                    on_finalize,
    const std::string&                              address    = "127.0.0.1:3000", 
    std::int32_t                                    timeout_ms = 5000);
  client           (const client&  that) = delete;
  client           (      client&& temp) = delete;
 ~client           () override;
  client& operator=(const client&  that) = delete;
  client& operator=(      client&& temp) = delete;
  
  void kill                ()
  {
    alive_ = false;
  }
  void make_request        ()
  {
    request_once_ = true;
  }
  void set_auto_request    (const bool auto_request)
  {
    request_auto_ = auto_request;
  }
  
signals:
  void on_request_internal ();
  void on_response_internal();
  void on_finalize_internal();

protected:
  zmq::context_t                           context_       {1};
  zmq::socket_t                            socket_        {context_, ZMQ_PAIR};
  
  std::function<void(proto::request&)>     on_request_    ;
  std::function<void(const proto::image&)> on_response_   ;
  std::function<void()>                    on_finalize_   ;
                                   
  std::future<void>                        future_        ;
  std::atomic_bool                         alive_         {true};
  std::atomic_bool                         request_once_  ;
  std::atomic_bool                         request_auto_  ;
  
  proto::request                           request_data_  ;
  std::mutex                               request_mutex_ ;
  std::condition_variable                  request_cv_    ;
  proto::image                             response_data_ ;
  std::mutex                               response_mutex_;
  std::condition_variable                  response_cv_   ;
};
}