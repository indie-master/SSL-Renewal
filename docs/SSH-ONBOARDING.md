# SSH Onboarding for Node Sync

## Automatic flow (from installer)

During `./install.sh main`, the installer can:

1. Generate `/root/.ssh/id_ed25519` if missing.
2. Run `ssh-copy-id` to each configured `user@host` node.

## If password auth is disabled on node

The installer will:

- report that automatic onboarding failed,
- print the public key,
- print exact manual `authorized_keys` steps,
- continue installation safely.

## Manual flow

### On main

```bash
cat /root/.ssh/id_ed25519.pub
```

### On node (as target SSH user)

```bash
mkdir -p ~/.ssh && chmod 700 ~/.ssh
echo '<PASTE_PUBLIC_KEY_HERE>' >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
```

### Verify from main

```bash
ssh user@node1.example.com "hostname"
```
