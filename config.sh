find_dataset() {
  mount -t zfs | awk 'BEGIN { ret = 1; } $3 == mountpoint { print $1; ret = 0; exit; } END { exit ret; }' mountpoint="$1"
}

dataset="$(find_dataset "$dir")" || { echo "could not find bootr's own dataset. are you sure it's at the root of a filesystem in your pool?"; exit 1; }
pool="$(cut -d/ -f1 <<< "$dataset")"
dataset_name="$(cut -d/ -f2- <<< "$dataset")"

echo "reading boot.cfg" >&2

efi="/boot/efi"
uuid="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
[ -f boot.cfg ] && source boot.cfg || fresh=true

if [ -n "$fresh" ]; then
  echo "first run detected" >&2
  cat > boot.cfg <<EOF
# vim: ft=sh
uuid="${uuid}"
EOF
  echo "generated base boot.cfg" >&2
  echo "exiting" >&2
  exit 1
fi

if [ "$uuid" = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx" ]; then
  echo "error: invalid UUID" >&2
  echo "you probably haven't edited your boot.cfg yet" >&2
  exit 1
fi
