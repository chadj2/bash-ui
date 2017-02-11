

# creates a space of 16 colors
echo_color16() {
	local _message=$1
	local _intensity=$(($2%2))
	local _color=$((30 + $2/2))
	echo -en "\e[${_intensity};${_color}m${_message}\e[0m"
}

echo "echo_color16"
for _i in {0..15}
do
	echo_color16 "X" $_i
done
echo

# creates a 6x6x6 RGB colorspace
echo_color216() {
	local _message=$1
	local _r=$2
	local _g=$3
	local _b=$4
	local _color=$((16 + 36*$_r + 6*$_g + $_b))
	echo -en "\e[38;5;${_color}m${_message}\e[0m"
}

echo "echo_color216"
for _r in {0..5}
do
	for _g in {0..5}
	do
		for _b in {0..5}
		do
			echo_color216 "X" $_r $_g $_b
		done
	done
	echo
done
echo

# creates 24 shades of grey
echo_color24() {
	local _message=$1
	local _intensity=$(( 16 + 216 + $2 ))
	echo -en "\e[38;5;${_intensity}m${_message}\e[0m"
}

echo "echo_color24"
for _i in {0..23}
do
	echo_color24 "X" $_i
done
echo

# 360 degrees of hue
echo_colorHSV() { 
	local _message=$1
	local _h=$2
	local _s=$3
	local _v=$4
	local _sector=$(($_h / 60))
	local _mag=$(($_h % 60 / 10))

	case $_sector in
		0)
		# add G
		echo_color216 $_message 5 $_mag 0
		;;
		1)
		# del R
		echo_color216 $_message 5 5 0
		;;
		2)
		# add B
		echo_color216 $_message 0 5 0
		;;
		3)
		# del G
		echo_color216 $_message 0 5 5
		;;
		4)
		# add R
		echo_color216 $_message 0 0 5
		;;
		5)
		# del B
		echo_color216 $_message 5 0 5
		;;
	esac
}

echo "echo_colorHSV"
for _h in {0..359}
do
	echo_colorHSV "X" $_h
done
echo
