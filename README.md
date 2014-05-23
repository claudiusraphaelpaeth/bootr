# bootr

  Kick-ass (U)EFI+LUKS+ZFS booting.

## Installation

  The recommended bootdisk for following this is [my ZFS-enabled Arch live system](http://nathan7.eu/stuff/archlinux-2014.01.26-dual.iso).

  I'm assuming you're calling your zpool `storage`, just replace it everywhere if you have an objection to that. `rpool` is a popular choice.
  I run Arch Linux, so my instructions will have `arch` sprinkled through them. Adjust to taste.
  I also happen to be somewhat obsessed with addressing things by UUID. You should be too.

### Set up your partitions

  Use `cgdisk`, because we're going GPT!
  Ensure you have one partition to use for your zpool, and one set up for EFI.
  Make sure that the EFI partition has its type set to `ef00`.
  I'm going to assume you've labeled them `storage` and `EFI`.
  This is what my setup looks like:

```
cgdisk 0.8.8

Disk Drive: /dev/sda
Size: 234441648, 111.8 GiB

Part. #     Size        Partition Type            Partition Name
----------------------------------------------------------------
            1007.0 KiB  free space
   1        110.8 GiB   Linux filesystem          storage
   2        1023.4 MiB  EFI System                EFI
```

### Create your LUKS partition

  * Generate a UUID: `export LUKS=$(uuidgen)`
  * Format your LUKS container: `cryptsetup luksFormat /dev/disk/by-partlabel/storage --uuid=$LUKS`
  * Open your LUKS container: `cryptsetup luksFormat /dev/disk/by-uuid/$LUKS $LUKS`

### Create a zpool

  Just `zpool create storage /dev/mapper/$LUKS`

### Create filesystems

  * One for your homedir: `zfs create -o mountpoint=/home storage/home`
  * One for your distro's rootfs: `zfs create storage/arch`


#### on Gentoo

  I prefer to keep my Portage tree outside my rootfs so my Portage tree doesn't get caught in rootfs snapshots.
  For that reason, I have a `storage/gentoo/root` filesystem and a seperate `storage/gentoo/portage` filesystem. My `/usr/portage` on Gentoo is a symlink to `/storage/gentoo/portage`.

### Bootstrap a system

  Extract your stage3, run debootstrap — whatever pleases your distro gods.
  For me this is `pacstrap /storage/arch base`.

### Pass our zpool over

  First, let's make sure that we have our zpool available to us inside.
  * `mkdir -pv /storage/arch/storage`
  * `mount --rbind /storage /storage/arch/storage`

### Get into your fresh system

  Chroot into your system, hook up all the special filesystems, etc.
  From an Arch live system, all of this is simply `arch-chroot /storage/arch /bin/su -`.

### Mounting (U)EFI partition

  Run `blkid`, and find your (U)EFI partition in the output.

  For me, it looks like this: `/dev/sda2: UUID="25B3-C8E7" TYPE="vfat" PARTLABEL="EFI" PARTUUID="984bf16f-ae4b-f54b-a254-aef3ac0b2b9a"`

  * Add a line to your `/etc/fstab` to match: `UUID=25B3-C8E7 /boot/efi vfat rw,noatime 0 2`
  * Make sure `/boot/efi` exists: `mkdir -pv /boot/efi`
  * And mount 'em all: `mount -a`

### Install bootr

  * Make a dataset for it: `zfs create storage/boot`
  * `git clone https://github.com/nathan7/bootr /storage/boot`
  * Create your first config: `/storage/boot/generate`
  * Edit your fresh config: `nano /storage/boot/boot.cfg`
  * Stick your LUKS partition's UUID in there (whatever the device in `/dev/mapper` is called)

### Make your distro bootable

  First things first, make yourself a `/boot/grub.cfg`.
  My Arch `grub.cfg` looks like this:
```
# vim: ft=grub
linux ${boot_path}/vmlinuz-linux zfs=${root_fs} cryptdevice=/dev/disk/by-uuid/${root_uuid}:${root_uuid} rw
initrd ${boot_path}/initramfs-linux.img
```

  `${root_uuid}` is passed through from your `boot.cfg`, `${root_fs}` is the filesystem it's on, `${root_path}` is the GRUB path to your filesystem root, and `${boot_path}` is the GRUB path to your `/boot`.

  Now that we've got that one down, let's mark your distro as bootable.
  `zfs set eu.nathan7:boot=true storage/arch` should do the trick.

  You'll also want to make sure your fresh system supports LUKS and ZFS.

#### on Arch

  Make sure your `/etc/mkinitpcio.conf` has `HOOKS="base udev block keyboard encrypt zfs"`.

  Add this to your `/etc/pacman.conf`:
```
[zfs]
SigLevel = Optional
Server = http://nathan7.eu/stuff/arch/$repo/$arch
```

  Run `pacman -Sy zfs` to make it all work.

### Generate your GRUB executable

  This is really all that bootr itself does, given that your system is set up as explained above.
  Simply run `/boot/efi/generate` and all should be sorted.

### Let go

  * We'll unmount everything and export the pool: `umount /storage /boot/efi`.
  * Let's exit the chroot: `exit`.
  * Now, back in our actual system: `zpool export storage`

### Reboot

  What it says on the tin.

### Welcome!

  Welcome to your fresh system!
  You might want to regenerate your initramfs to include the `zpool.cache` and `/etc/hostid` generated during your first boot.
  Have fun!

## Extras
### Signing your EFI executable

  * Generate a key: `openssl req -new -x509 -newkey rsa:2048 -keyout boot.key -out boot.crt -days 365`
  * Add `sign="boot"` to your boot.cfg
  * Regenerate your boot image: `./generate-image`

