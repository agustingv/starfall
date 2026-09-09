project(
  'raylib',
  'c',
  version : '5.5',
  license : 'Zlib',
  meson_version : '>= 1.1.0',
)

cc = meson.get_compiler('c')
sh = find_program('sh')

# raylib builds in-tree; point its Makefile at src/ and copy the archive out.
libraylib = custom_target(
  'libraylib',
  output : 'libraylib.a',
  command : [sh, files('build-raylib.sh'), meson.current_source_dir() / 'src', '@OUTPUT@'],
  console : true,
  build_by_default : true,
)

# System libraries the Linux desktop (GLFW + X11 + GL) backend links against.
# Resolved with find_library rather than pkg-config dependency() so Meson does
# not try to hand them to valac as Vala packages.
raylib_system_deps = [
  cc.find_library('m'),
  cc.find_library('dl', required : false),
  cc.find_library('pthread', required : false),
  cc.find_library('rt', required : false),
  cc.find_library('GL'),
  cc.find_library('X11'),
  cc.find_library('Xrandr'),
  cc.find_library('Xinerama'),
  cc.find_library('Xi'),
  cc.find_library('Xcursor'),
  cc.find_library('Xext', required : false),
  cc.find_library('Xfixes', required : false),
]

raylib_dep = declare_dependency(
  link_with : libraylib,
  include_directories : include_directories('src'),
  dependencies : raylib_system_deps,
)

meson.override_dependency('raylib', raylib_dep)
