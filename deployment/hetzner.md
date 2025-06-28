# How to setup Hetzner server
1. Create new server and add SSH key to it
2. Create new user: adduser ondrej
3. Grant priviliges: usermod -aG sudo ondrej
4. Allow SSH connect to new user: rsync --archive --chown=ondrej:ondrej ~/.ssh /home/ondrej
5. Test SSH connect to new user: ssh -i /Users/ondrejrohon/.ssh/hetzner ondrej@116.203.18.8
