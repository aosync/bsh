# !!! Important build variables !!!

# TODO: Support library building.

CC=${CC:-cc}		# Compiler for target
EXEC="lowbatteryd"  # Executable name
SRC="src"			# source directory for target, all .c files are taken from there, non recursive.
SRCI=""				# individual sources, if you prefer to have finer control
LIBS="$(pkg-config --cflags --libs x11) -O3 -pipe -march=native"	# CC arguments
BUILD="build"		# build directory for target


target_exec() {
	# Setup folders and variables for the build
	set +f
	[ ! -d build ] && mkdir build
	[ ! $SRC = "." ] && [ ! -d "$BUILD/$SRC" ] && mkdir "$BUILD/$SRC" # This creates the build folder if SRC is not .
	tobuild=""
	objects=""

	scan_objects_to_build() {
		for s in $SRC/*.c $SRCI; do
			objects="$BUILD/$s.o $objects"
			[ ! -f "$BUILD/$s.o" ] || [ -n "$(find $s -newer $BUILD/$s.o)" ] && tobuild="$tobuild $s" && relink="y"
		done
	}
	scan_objects_to_build

	# Get current build objects to build count and cflags
	on="$(echo "$objects" | md5sum)"
	on="${on%% *}"
	ln="$(echo $LIBS | md5sum)"
	ln="${ln%% *}"

	# Get the same values but for previous build
	[ -f $BUILD/$SRC/meta ] && read -r o l < $BUILD/$SRC/meta || relink="y"

	# If object count is different, relink (this is is needed if a source file is deleted). If cflags have changed, recompile everything
	[ ! "$on" = "$o" ] && relink="y"
	[ ! "$ln" = "$l" ] && [ -f $BUILD/meta ] && rm $BUILD/$SRC/*.o && objects="" && tobuild="" && scan_objects_to_build

	# If no executable, relink anyway
	[ ! -f $EXEC ] && relink="y"

	# If no need to relink, there is nothing to do.
	[ -z "$relink" ] && { echo "Nothing to do."; exit 0; }

	# Build
	for s in $tobuild; do
		echo "CC	$BUILD/$s.o"
		${CC:-gcc} -c -o "$BUILD/$s.o" $s $LIBS || { echo "Build failed at file $s. Exiting." ; exit 1; }
	done

	# Link
	echo "Linking	$objects"
	$CC -o $EXEC $objects $LIBS || exit 1

	# Save current compilation meta in the build folder
	echo "$on $ln" > $BUILD/$SRC/meta
}
target_exec
