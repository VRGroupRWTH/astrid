##################################################    Project     ##################################################
cmake_minimum_required(VERSION 3.23 FATAL_ERROR)
project               (astrid VERSION 1.0 LANGUAGES C CXX)
list                  (APPEND CMAKE_MODULE_PATH ${PROJECT_SOURCE_DIR}/cmake)
set_property          (GLOBAL PROPERTY USE_FOLDERS ON)
set                   (CMAKE_CXX_STANDARD 17)

include               (set_max_warning_level)
set_max_warning_level ()

##################################################    Sources     ##################################################
file(GLOB_RECURSE PROJECT_HEADERS include/*.h include/*.hpp)
file(GLOB_RECURSE PROJECT_SOURCES source/*.c source/*.cpp source/*.cu)
file(GLOB_RECURSE PROJECT_PROTOS proto/*.proto)
file(GLOB_RECURSE PROJECT_UIS ui/*.ui)
file(GLOB_RECURSE PROJECT_CMAKE_UTILS cmake/*.cmake)
file(GLOB_RECURSE PROJECT_MISC *.md *.txt)
set (PROJECT_FILES 
  ${PROJECT_HEADERS} 
  ${PROJECT_SOURCES} 
  ${PROJECT_PROTOS} 
  ${PROJECT_UIS} 
  ${PROJECT_CMAKE_UTILS} 
  ${PROJECT_MISC})

include            (assign_source_group)
assign_source_group(${PROJECT_FILES})

##################################################  Dependencies  ##################################################
include(import_library)

find_package(astray CONFIG REQUIRED)
list        (APPEND PROJECT_LIBRARIES astray)

find_package(cppzmq CONFIG REQUIRED)
list        (APPEND PROJECT_LIBRARIES cppzmq)

find_package(cxxopts CONFIG REQUIRED)
list        (APPEND PROJECT_LIBRARIES cxxopts::cxxopts)

find_package(Protobuf CONFIG REQUIRED)
list        (APPEND PROJECT_LIBRARIES protobuf::libprotoc protobuf::libprotobuf)

find_package(Qt5Widgets REQUIRED)
list        (APPEND PROJECT_LIBRARIES Qt5::Widgets)
qt5_wrap_ui (PROJECT_GENERATED_UIS ${PROJECT_UIS})
list        (APPEND PROJECT_FILES ${PROJECT_GENERATED_UIS})
set         (CMAKE_AUTOMOC ON)
set         (CMAKE_AUTORCC ON)
  
find_package(ZeroMQ CONFIG REQUIRED)
list        (APPEND PROJECT_LIBRARIES libzmq)

enable_language(CUDA) # Hack.
  
##################################################    Targets     ##################################################
add_executable(${PROJECT_NAME} ${PROJECT_FILES})
target_include_directories(${PROJECT_NAME} PUBLIC 
  $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
  $<BUILD_INTERFACE:${CMAKE_CURRENT_BINARY_DIR}>
  $<INSTALL_INTERFACE:include> PRIVATE source)
target_include_directories(${PROJECT_NAME} PUBLIC ${PROJECT_INCLUDE_DIRS})
target_link_libraries     (${PROJECT_NAME} PUBLIC ${PROJECT_LIBRARIES})
target_compile_definitions(${PROJECT_NAME} PUBLIC ${PROJECT_COMPILE_DEFINITIONS})
target_compile_options    (${PROJECT_NAME} PUBLIC ${PROJECT_COMPILE_OPTIONS})
set_target_properties     (${PROJECT_NAME} PROPERTIES LINKER_LANGUAGE CXX)

##################################################   Prebuild     ##################################################
protobuf_generate(LANGUAGE cpp TARGET ${PROJECT_NAME} PROTOS ${PROJECT_PROTOS} IMPORT_DIRS proto)

##################################################  Installation  ##################################################
install(TARGETS ${PROJECT_NAME} EXPORT ${PROJECT_NAME}-config RUNTIME DESTINATION bin)
install(EXPORT  ${PROJECT_NAME}-config DESTINATION cmake)
export (TARGETS ${PROJECT_NAME} FILE ${PROJECT_NAME}-config.cmake)