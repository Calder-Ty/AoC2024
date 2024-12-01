set -e

if [[ -z $1 ]]; then
	echo "usage: $0 DIRNAME"
	exit 1
fi

DIRNAME=$1

cp -r "./template" $DIRNAME

pushd $DIRNAME
sed -i "s/template/$DIRNAME/g" build.zig
sed -i "s/template/$DIRNAME/g" build.zig.zon
popd
