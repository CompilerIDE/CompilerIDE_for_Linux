cmake_minimum_required(VERSION 3.22)
project(CompilerIDE VERSION 4.0.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)
set(CMAKE_INCLUDE_CURRENT_DIR ON)

include(GNUInstallDirs)

if(COMPILERIDE_QT_DIR AND EXISTS "${COMPILERIDE_QT_DIR}/lib/cmake/Qt6")
    list(PREPEND CMAKE_PREFIX_PATH "${COMPILERIDE_QT_DIR}")
endif()

if(UNIX AND NOT APPLE)
    if(CMAKE_INSTALL_PREFIX_INITIALIZED_TO_DEFAULT)
        set(CMAKE_INSTALL_PREFIX "/opt/compileride" CACHE PATH "Install prefix" FORCE)
    endif()
endif()

find_package(Qt6 6.11.2 REQUIRED COMPONENTS
    Core Gui Widgets Network Charts Pdf PdfWidgets
    WebEngineCore WebEngineWidgets WebEngineQuick
    WebChannel Qml Quick QuickWidgets QuickControls2
)

if(COMPILERIDE_QT_DIR AND EXISTS "${COMPILERIDE_QT_DIR}/lib/cmake/Qt6")
else()
    get_filename_component(COMPILERIDE_QT_DIR "${Qt6_DIR}/../../.." ABSOLUTE)
endif()
set(COMPILERIDE_QT_DIR "${COMPILERIDE_QT_DIR}" CACHE PATH "打包时使用的 Qt 安装前缀" FORCE)
message(STATUS "打包使用的 Qt 安装前缀: ${COMPILERIDE_QT_DIR}")

qt_add_executable(CompilerIDE main.cpp resources.qrc)

target_link_libraries(CompilerIDE PRIVATE
    Qt6::Core Qt6::Gui Qt6::Widgets Qt6::Network
    Qt6::Charts Qt6::Pdf Qt6::PdfWidgets
    Qt6::WebEngineCore Qt6::WebEngineWidgets Qt6::WebEngineQuick
    Qt6::WebChannel Qt6::Qml Qt6::Quick Qt6::QuickWidgets Qt6::QuickControls2
)

if(UNIX AND NOT APPLE)
    find_library(UTIL_LIBRARY util REQUIRED)
    target_link_libraries(CompilerIDE PRIVATE ${UTIL_LIBRARY})
    set_target_properties(CompilerIDE PROPERTIES
        INSTALL_RPATH "$ORIGIN/../lib"
        BUILD_WITH_INSTALL_RPATH OFF
        INSTALL_RPATH_USE_LINK_PATH FALSE
    )
endif()

install(TARGETS CompilerIDE RUNTIME DESTINATION bin)
install(FILES packaging/qt.conf DESTINATION bin)
install(PROGRAMS packaging/CompilerIDE-launcher
    DESTINATION /usr/bin
    RENAME CompilerIDE
)

install(FILES packaging/cn.compileride.CompilerIDE.desktop
    DESTINATION /usr/share/applications
)
install(FILES icons/compileride.png
    DESTINATION /usr/share/icons/hicolor/256x256/apps
    RENAME compileride.png
    OPTIONAL
)
install(FILES icons/CompilerIDE_logo.png
    DESTINATION /usr/share/icons/hicolor/256x256/apps
    RENAME CompilerIDE_logo.png
    OPTIONAL
)

set(COMPILERIDE_QT_LIBS
    # 主依赖
    Core Gui Widgets Network
    Charts Pdf PdfWidgets
    WebEngineCore WebEngineWidgets WebEngineQuick
    WebChannel Qml Quick QuickWidgets QuickControls2
    # Qt Quick 相关
    Concurrent DBus OpenGL OpenGLWidgets PrintSupport Svg SvgWidgets
    QmlMeta QmlModels QmlWorkerScript QmlLocalStorage QmlXmlListModel
    QuickTemplates2 QuickLayouts
    # 平台插件依赖的私有库（关键！）
    XcbQpa
    WaylandClient WaylandEglClientHwIntegration
    WaylandCompositor WaylandEglCompositorHwIntegration
    # WebEngine 隐式依赖
    Positioning PositioningQuick
    LabsPlatform LabsQmlModels
    ShaderTools Quick3DUtils
    # 随包发布的 QML 模块 / 插件在运行时 dlopen 的 Qt 库。
    # 少任何一个，对应的 QML 模块或插件都会加载失败（例如 QtQuick.Controls 需要
    # QuickControls2Impl 与各风格库，QtWebEngine 需要 WebEngineQuickDelegatesQml 等）。
    ChartsQml PdfQuick Sql WebChannelQuick WebEngineQuickDelegatesQml
    QuickControls2Impl
    QuickControls2Basic QuickControls2BasicStyleImpl
    QuickControls2Fusion QuickControls2FusionStyleImpl
    QuickControls2Imagine QuickControls2ImagineStyleImpl
    QuickControls2Material QuickControls2MaterialStyleImpl
    QuickControls2Universal QuickControls2UniversalStyleImpl
    QuickControls2FluentWinUI3StyleImpl
    QuickDialogs2 QuickDialogs2QuickImpl QuickDialogs2Utils
    QuickEffects QuickParticles QuickShapes QuickShapesDesignHelpers
    QuickTimeline QuickTimelineBlendTrees
    QuickVectorImage QuickVectorImageGenerator QuickVectorImageHelpers
    EglFSDeviceIntegration EglFsKmsGbmSupport EglFsKmsSupport WlShellIntegration
    StateMachine StateMachineQml QmlDesignSupport QuickControls2FluentWinUI3 QuickControls2Native
)

foreach(_qtlib ${COMPILERIDE_QT_LIBS})
    file(GLOB _files "${COMPILERIDE_QT_DIR}/lib/libQt6${_qtlib}.so.6*")
    if(_files)
        install(FILES ${_files} DESTINATION lib)
    endif()
endforeach()

file(GLOB _icu_files "${COMPILERIDE_QT_DIR}/lib/libicu*.so.*")
if(_icu_files)
    install(FILES ${_icu_files} DESTINATION lib)
endif()

# ============================================
# 插件
# ============================================
set(COMPILERIDE_QT_PLUGIN_DIRS
    platforms xcbglintegrations imageformats iconengines
    platforminputcontexts platformthemes styles tls
    networkinformation egldeviceintegrations generic
    wayland-decoration-client wayland-graphics-integration-client
    wayland-shell-integration
)
foreach(_dir ${COMPILERIDE_QT_PLUGIN_DIRS})
    if(EXISTS "${COMPILERIDE_QT_DIR}/plugins/${_dir}")
        install(DIRECTORY "${COMPILERIDE_QT_DIR}/plugins/${_dir}/"
            DESTINATION plugins/${_dir}
            FILES_MATCHING PATTERN "*.so"
            PATTERN "libqtvirtualkeyboardplugin.so" EXCLUDE)
    endif()
endforeach()

# ============================================
# QML 模块
# ============================================
set(COMPILERIDE_QML_MODULES
    QtQml QtQuick QtQuick.2 QtWebEngine QtWebChannel QtCharts
    QtPositioning QtLabsPlatform
)
foreach(_mod ${COMPILERIDE_QML_MODULES})
    if(EXISTS "${COMPILERIDE_QT_DIR}/qml/${_mod}")
        install(DIRECTORY "${COMPILERIDE_QT_DIR}/qml/${_mod}/"
            DESTINATION qml/${_mod}
            PATTERN "VirtualKeyboard" EXCLUDE)
    endif()
endforeach()

# ============================================
# WebEngine 组件
# ============================================
install(PROGRAMS "${COMPILERIDE_QT_DIR}/libexec/QtWebEngineProcess"
    DESTINATION libexec
    OPTIONAL
)
foreach(_res
    icudtl.dat
    qtwebengine_devtools_resources.pak
    qtwebengine_resources.pak
    qtwebengine_resources_100p.pak
    qtwebengine_resources_200p.pak
    v8_context_snapshot.bin
)
    if(EXISTS "${COMPILERIDE_QT_DIR}/resources/${_res}")
        install(FILES "${COMPILERIDE_QT_DIR}/resources/${_res}"
            DESTINATION resources)
    endif()
endforeach()
if(EXISTS "${COMPILERIDE_QT_DIR}/translations/qtwebengine_locales")
    install(DIRECTORY "${COMPILERIDE_QT_DIR}/translations/qtwebengine_locales/"
        DESTINATION translations/qtwebengine_locales)
endif()

install(SCRIPT "${CMAKE_CURRENT_SOURCE_DIR}/packaging/fix_rpath.cmake")

set(CPACK_PACKAGE_NAME "compileride")
set(CPACK_PACKAGE_VENDOR "Compiler IDE Team")
set(CPACK_PACKAGE_CONTACT "Compiler IDE Team")
set(CPACK_PACKAGE_DESCRIPTION_SUMMARY "Modern C++ Integrated Development Environment")
set(CPACK_PACKAGE_DESCRIPTION "Compiler IDE is a modern C++ IDE with built-in data tester, competition mode, Luogu problem fetcher, stress tester and many other features.")
set(CPACK_PACKAGE_VERSION ${PROJECT_VERSION})
set(CPACK_GENERATOR "DEB")
set(CPACK_DEBIAN_FILE_NAME "DEB-DEFAULT")
set(CPACK_DEBIAN_PACKAGE_NAME "compileride")
set(CPACK_DEBIAN_PACKAGE_SECTION "devel")
set(CPACK_DEBIAN_PACKAGE_PRIORITY "optional")
set(CPACK_DEBIAN_PACKAGE_MAINTAINER "Compiler IDE Team")
set(CPACK_DEBIAN_PACKAGE_HOMEPAGE "https://github.com/CompilerIDE/CompilerIDE")
set(CPACK_DEBIAN_PACKAGE_SHLIBDEPS OFF)

set(COMPILERIDE_DEB_DEPENDS
    # 基础运行库
    libc6 libstdc++6 libgcc-s1 zlib1g libzstd1 libbrotli1
    "libssl3t64 | libssl3" ca-certificates
    # OpenGL / 字体 / D-Bus
    libgl1 libegl1 libglx0 libopengl0
    libfontconfig1 libfreetype6 libexpat1 libdbus-1-3
    # QtWebEngine（Chromium）必需的系统库
    libnss3 libnspr4 "libasound2t64 | libasound2"
    libgbm1 libdrm2 libudev1
    "libglib2.0-0t64 | libglib2.0-0" libgssapi-krb5-2
    # X11 / xcb 平台插件
    libx11-6 libx11-xcb1 libxext6 libxfixes3 libxrandr2 libxcomposite1 libxdamage1 libxtst6
    libxcb1 libxcb-icccm4 libxcb-image0 libxcb-keysyms1 libxcb-randr0 libxcb-render0
    libxcb-render-util0 libxcb-shape0 libxcb-shm0 libxcb-sync1 libxcb-util1 libxcb-xfixes0
    libxcb-xkb1 libxcb-dri3-0 libxcb-glx0 libxcb-cursor0
    libxkbcommon0 libxkbcommon-x11-0 libxkbfile1
    # Wayland 插件（也随包发布）
    libwayland-client0 libwayland-cursor0 libwayland-egl1 libwayland-server0
    # 集成终端（xterm.js）与自更新（pkexec + apt-get）
    libjs-xterm pkexec apt dpkg
)
string(JOIN ", " COMPILERIDE_DEB_DEPENDS_STRING ${COMPILERIDE_DEB_DEPENDS})
set(CPACK_DEBIAN_PACKAGE_DEPENDS "${COMPILERIDE_DEB_DEPENDS_STRING}")

set(COMPILERIDE_DEB_RECOMMENDS
    g++ gdb clangd
    "libgtk-3-0t64 | libgtk-3-0"
    fonts-noto-cjk
)
string(JOIN ", " COMPILERIDE_DEB_RECOMMENDS_STRING ${COMPILERIDE_DEB_RECOMMENDS})
set(CPACK_DEBIAN_PACKAGE_RECOMMENDS "${COMPILERIDE_DEB_RECOMMENDS_STRING}")

set(CPACK_PACKAGING_INSTALL_PREFIX "/opt/compileride")
set(CPACK_SET_DESTDIR ON)

set(CPACK_PACKAGE_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/Setup")

include(CPack)
