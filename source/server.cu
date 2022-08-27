#include <astrid/server.hpp>

#include <iostream>
#include <string>
#include <vector>

namespace ast
{
server::server(const std::int32_t port)
{
  if (communicator_.rank() == 0)
  {
    const auto address = std::string("tcp://*:") + std::to_string(port);
    socket_.bind(address);
    std::cout << "Socket bound at: " << address << ".\n";
  }
}

void server::run   ()
{
  proto::request            request     ;
  proto::image              response    ;
  std::int32_t              message_size;
  std::vector<std::uint8_t> message_data;
  image_type                image       ;

  while (!request.terminate())
  {
    if (communicator_.rank() == 0)
    {
      zmq::message_t message;
      socket_.recv(message, zmq::recv_flags::none);

      message_size = static_cast<std::int32_t>(message.size());
      message_data.resize(message.size());
      std::copy_n(static_cast<std::uint8_t*>(message.data()), message.size(), message_data.begin());
    }
    
#ifdef ASTRAY_USE_MPI
    communicator_.bcast (&message_size      , 1           , mpi::data_type(MPI_INT ));
    message_data .resize(message_size);
    communicator_.bcast (message_data.data(), message_size, mpi::data_type(MPI_BYTE));
#endif
    request.ParseFromArray(message_data.data(), static_cast<std::int32_t>(message_data.size()));
    
    update(request);
    std::visit([&] (auto& ray_tracer) { image = ray_tracer.render_frame(); }, ray_tracer_.value());

    if (communicator_.rank() == 0)
    {
      response.set_data(static_cast<void*>(image.data.data()), image.data.size() * sizeof(vector3<std::uint8_t>));
      response.mutable_size()->set_x (image.size[0]);
      response.mutable_size()->set_y (image.size[1]);
      auto string = response.SerializeAsString();

      zmq::message_t message(string.begin(), string.end());
      socket_.send(message, zmq::send_flags::none);
    }
  }
}

void server::update(const proto::request& request)
{
  if (request.has_metric())
  {
    ray_tracer_.reset();

#if THRUST_DEVICE_SYSTEM == THRUST_DEVICE_SYSTEM_CUDA
      cudaDeviceReset();
#endif

    ray_tracer_.emplace();

    if      (request.metric() == "alcubierre")
      ray_tracer_->emplace<ray_tracer<metrics::alcubierre                          <scalar_type>, motion_type>>();
    else if (request.metric() == "barriola_vilenkin")
      ray_tracer_->emplace<ray_tracer<metrics::barriola_vilenkin                   <scalar_type>, motion_type>>();
    else if (request.metric() == "bertotti_kasner")
      ray_tracer_->emplace<ray_tracer<metrics::bertotti_kasner                     <scalar_type>, motion_type>>();
    else if (request.metric() == "bessel")
      ray_tracer_->emplace<ray_tracer<metrics::bessel                              <scalar_type>, motion_type>>();
    else if (request.metric() == "de_sitter")
      ray_tracer_->emplace<ray_tracer<metrics::de_sitter                           <scalar_type>, motion_type>>();
    else if (request.metric() == "einstein_rosen_weber_wheeler_bonnor")
      ray_tracer_->emplace<ray_tracer<metrics::einstein_rosen_weber_wheeler_bonnor <scalar_type>, motion_type>>();
    else if (request.metric() == "friedman_lemaitre_robertson_walker")
      ray_tracer_->emplace<ray_tracer<metrics::friedman_lemaitre_robertson_walker  <scalar_type>, motion_type>>();
    else if (request.metric() == "goedel")
      ray_tracer_->emplace<ray_tracer<metrics::goedel                              <scalar_type>, motion_type>>();
    else if (request.metric() == "janis_newman_winicour")
      ray_tracer_->emplace<ray_tracer<metrics::janis_newman_winicour               <scalar_type>, motion_type>>();
    else if (request.metric() == "kastor_traschen")
      ray_tracer_->emplace<ray_tracer<metrics::kastor_traschen                     <scalar_type>, motion_type>>();
    else if (request.metric() == "kerr")
      ray_tracer_->emplace<ray_tracer<metrics::kerr                                <scalar_type>, motion_type>>();
    else if (request.metric() == "kottler")
      ray_tracer_->emplace<ray_tracer<metrics::kottler                             <scalar_type>, motion_type>>();
    else if (request.metric() == "minkowski")
      ray_tracer_->emplace<ray_tracer<metrics::minkowski                           <scalar_type>, motion_type>>();
    else if (request.metric() == "morris_thorne")
      ray_tracer_->emplace<ray_tracer<metrics::morris_thorne                       <scalar_type>, motion_type>>();
    else if (request.metric() == "reissner_nordstroem")
      ray_tracer_->emplace<ray_tracer<metrics::reissner_nordstroem                 <scalar_type>, motion_type>>();
    else if (request.metric() == "reissner_nordstroem_extreme_dihole")
      ray_tracer_->emplace<ray_tracer<metrics::reissner_nordstroem_extreme_dihole  <scalar_type>, motion_type>>();
    else if (request.metric() == "schwarzschild")
      ray_tracer_->emplace<ray_tracer<metrics::schwarzschild                       <scalar_type>, motion_type>>();
    else if (request.metric() == "schwarzschild_cosmic_string")
      ray_tracer_->emplace<ray_tracer<metrics::schwarzschild_cosmic_string         <scalar_type>, motion_type>>();
  }

  std::visit([&] (auto& ray_tracer)
  {
    if (request.has_image_size       ())
      ray_tracer.set_image_size      ({request.image_size().x(), request.image_size().y()});
    if (request.has_iterations       ())
      ray_tracer.set_iterations      (request.iterations());
    if (request.has_lambda_step_size ())
      ray_tracer.set_lambda_step_size(request.lambda_step_size());
    if (request.has_lambda           ())
      ray_tracer.set_lambda          (request.lambda());
    if (request.has_debug            ())
      ray_tracer.set_debug           (request.debug());
    
    if (request.has_bounds          ())
    {
      auto& bounds = request.bounds();
      auto& lower  = bounds .lower ();
      auto& upper  = bounds .upper ();
      ray_tracer.set_bounds(aabb4<scalar_type>(
        vector4<scalar_type>(lower.t(), lower.x(), lower.y(), lower.z()),
        vector4<scalar_type>(upper.t(), upper.x(), upper.y(), upper.z())));
    }

    if (request.has_transform       ())
    {
      auto& transform = request.transform();

      if (transform.has_time          ())
        ray_tracer.observer().set_coordinate_time(request.transform().time());

      if (transform.has_position      ())
      {
        auto& position = transform.position();
        ray_tracer.observer().transform().translation = {position.x(), position.y(), position.z()};
      }
      
      if (transform.has_rotation_euler())
      {
        auto& rotation = transform.rotation_euler();
        ray_tracer.observer().transform().rotation_from_euler({to_radians(rotation.x()), to_radians(rotation.y()), to_radians(rotation.z())});
      }

      if (transform.has_look_at_origin() && transform.look_at_origin())
        ray_tracer.observer().transform().look_at({0, 0, 0});
    }

    if (request.has_projection      ())
    {
      const auto& projection   = request.projection();
      const auto& image_size   = ray_tracer.image_size();
      const auto  aspect_ratio = static_cast<scalar_type>(image_size[0]) / static_cast<scalar_type>(image_size[1]);

      if (projection.has_type())
      {
        if      (projection.type() == "perspective" )
          ray_tracer.observer().set_projection(perspective_projection <scalar_type>{to_radians<scalar_type>(75), aspect_ratio});
        else if (projection.type() == "orthographic")
          ray_tracer.observer().set_projection(orthographic_projection<scalar_type>{1, aspect_ratio});
      }

      if      (std::holds_alternative<perspective_projection <scalar_type>>(ray_tracer.observer().projection()))
      {
        auto& cast_projection = std::get<perspective_projection<scalar_type>>(ray_tracer.observer().projection());

        if (request.has_image_size())
          cast_projection.aspect_ratio = aspect_ratio;
        if (projection.has_y_field_of_view())
          cast_projection.fov_y        = to_radians(projection.y_field_of_view());
        if (projection.has_focal_length   ())
          cast_projection.focal_length = projection.focal_length   ();
        if (projection.has_near_clip      ())
          cast_projection.near_clip    = projection.near_clip      ();
        if (projection.has_far_clip       ())
          cast_projection.far_clip     = projection.far_clip       ();
      }
      else if (std::holds_alternative<orthographic_projection<scalar_type>>(ray_tracer.observer().projection()))
      {
        auto& cast_projection = std::get<orthographic_projection<scalar_type>>(ray_tracer.observer().projection());
      
        if (request.has_image_size())
          cast_projection.aspect_ratio = aspect_ratio;
        if (projection.has_height         ())
          cast_projection.height       = projection.height         ();
        if (projection.has_near_clip      ())
          cast_projection.near_clip    = projection.near_clip      ();
        if (projection.has_far_clip       ())
          cast_projection.far_clip     = projection.far_clip       ();
      }
    }

    if (request.has_background_image())
    {
      auto& background = request.background_image();

      image_type image(vector2<std::int32_t>{background.size().x(), background.size().y()});
      std::copy_n(background.data().data(), background.data().size(), reinterpret_cast<std::uint8_t*>(image.data.data()));
      ray_tracer.set_background(image);
    }
  }, ray_tracer_.value());
}
}