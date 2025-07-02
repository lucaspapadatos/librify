cmake_minimum_required(VERSION 3.16)

project(Librify VERSION 0.1 LANGUAGES CXX)
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)
set(CMAKE_AUTOUIC ON)
set(Qt6_NO_VULKAN ON)

# --- Qt Setup ---
find_package(Qt6 6.5 REQUIRED COMPONENTS
    Core Gui Qml Quick Network Widgets Multimedia QuickControls2 Concurrent Core5Compat
)
find_package(TagLib REQUIRED)

# --- Source & Header Files ---
file(GLOB_RECURSE PROJECT_SOURCES src/*.cpp)
file(GLOB_RECURSE PROJECT_HEADERS include/*.h)
file(GLOB_RECURSE FONT_FILES RELATIVE ${CMAKE_CURRENT_SOURCE_DIR} "fonts/*")
file(GLOB_RECURSE ICON_FILES RELATIVE ${CMAKE_CURRENT_SOURCE_DIR} "icons/*")

set(RESOURCE_FILES
    ${FONT_FILES}
    ${ICON_FILES}
)

qt_add_executable(Librify
    ${PROJECT_SOURCES}
    ${PROJECT_HEADERS}
)

target_include_directories(Librify PRIVATE include)

qt_add_resources(Librify "qml_resources" FILES qml/qml.qrc)
qt_add_resources(Librify "resources" FILES ${RESOURCE_FILES})

target_link_libraries(Librify PRIVATE
    Qt6::Core Qt6::Gui Qt6::Qml Qt6::Quick Qt6::Network Qt6::Widgets
    Qt6::Multimedia Qt6::QuickControls2 Qt6::Concurrent Qt6::Core5Compat
    TagLib::TagLib
)
