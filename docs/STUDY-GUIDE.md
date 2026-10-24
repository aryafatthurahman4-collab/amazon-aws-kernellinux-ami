# Amazon Linux Reference — Complete Study Guide

> A comprehensive reference covering Amazon Linux 2023, AL2027 (Preview), kernel management, migration paths, networking, container images, and operational best practices.

---

## Table of Contents

1. [Amazon Linux Versions Overview](#1-amazon-linux-versions-overview)
2. [Amazon Linux 2023 (AL2023) Deep Dive](#2-amazon-linux-2023-deep-dive)
3. [Amazon Linux 2027 (Preview)](#3-amazon-linux-2027-preview)
4. [Kernel & Package Management](#4-kernel--package-management)
5. [AL2 → AL2023 Migration Guide](#5-al2--al2023-migration-guide)
6. [Networking (systemd-networkd & ec2-net-utils)](#6-networking)
7. [Container Images & Docker](#7-container-images--docker)
8. [AMI Management & SSM](#8-ami-management--ssm)
9. [Security Best Practices](#9-security-best-practices)
10. [Infrastructure as Code](#10-infrastructure-as-code)
11. [Essential Commands Cheat Sheet](#11-essential-commands-cheat-sheet)
12. [Key Links & Resources](#12-key-links--resources)

---

## 1. Amazon Linux Versions Overview

| Version | Status | Support Until | Docker Tag | Package Manager |
|---------|--------|--------------|------------|-----------------|
| **AL2027** | Preview ⚡ | ~2032 | `2027-minimal` | DNF |
| **AL2023** | GA ✅ (Recommended) | 2028 | `2023`, `latest` | DNF |
| **AL2** | EOL Soon ⚠️ | Jun 30, 2026 | `2` | YUM |
| **AL1 (AMI)** | Deprecated ☠️ | Jan 2024 | `2018.03`, `1` | YUM |

### Lifecycle Model
- **Major releases**: Every 2 years
- **Quarterly updates**: During first 2 years (bug fixes + new features)
- **Maintenance period**: 3 years after initial 2-year active period
- **Total LTS**: 5 years per major version

---

## 2. Amazon Linux 2023 Deep Dive

### Core Characteristics
- **Based on**: Multiple upstreams (Fedora 34/35/36, CentOS 9 Stream, kernel.org LTS)
- **Kernel**: 6.1 LTS from kernel.org (chosen independently from other distros)
- **Package Manager**: DNF (successor to YUM; `yum` is symlinked)
- **Init System**: systemd
- **EBS Default**: gp3 (20% cheaper than gp2)
- **Boot Mode**: UEFI Preferred + Secure Boot
- **Architectures**: x86_64 (amd64), aarch64 (arm64)

### Three Major Benefits
1. **High Security Standard**: Preconfigured crypto policies, kernel hardening
2. **Predictable Lifecycle**: 5-year LTS, quarterly updates
3. **Deterministic Updates**: Version-locked repositories (no surprise updates)

### Deterministic Updates (Key Feature)
```
# By default, dnf update does NOTHING (locked to AMI version)
$ sudo dnf update
→ Nothing to do. Complete!

# Check what updates are available
$ dnf check-release-update

# Upgrade to a specific version
$ sudo dnf upgrade --releasever=2023.0.20230308

# Check individual package updates for a version
$ dnf check-update --releasever=2023.0.20230308
```

This ensures **all instances from the same AMI have identical packages**, supporting immutable infrastructure patterns.

---

## 3. Amazon Linux 2027 (Preview)

### ⚠️ Preview Limitations
- **Evaluation and testing ONLY** — not for production
- **No automatic updates** by default (including critical security)
- Successor to AL2023

### Key Links
- Product: https://aws.amazon.com/linux/amazon-linux-2027/
- User Guide: https://docs.aws.amazon.com/linux/al2027/ug/what-is-amazon-linux-2027.html
- vs AL2023: https://docs.aws.amazon.com/linux/al2027/ug/compare-with-al2023.html
- Security: https://alas.aws.amazon.com/alas2027.html

---

## 4. Kernel & Package Management

### DNF Commands Reference

| Command | Description |
|---------|-------------|
| `dnf search <pkg>` | Search for packages |
| `dnf install <pkg>` | Install a package |
| `dnf remove <pkg>` | Remove a package |
| `dnf list installed` | List all installed packages |
| `dnf info <pkg>` | Package details |
| `dnf check-release-update` | Check for release updates |
| `dnf check-update --releasever=X` | List package updates for version X |
| `dnf upgrade --releasever=X` | Upgrade to version X |
| `dnf download --source <pkg>` | Download source RPM |

### Key Notes
- `yum` still works — it's a symlink to `dnf-3`
- Source code available via SRPM: `sudo dnf install -y 'dnf-command(download)' && dnf download --source bash`

---

## 5. AL2 → AL2023 Migration Guide

### Critical Changes

| Area | AL2 | AL2023 | Impact |
|------|-----|--------|--------|
| **Package Manager** | YUM | DNF | Low — yum is symlinked |
| **Update Model** | Rolling | Deterministic (locked repos) | **HIGH** — scripts need updating |
| **Networking** | ISC dhclient | systemd-networkd | **HIGH** — config files change |
| **Logging** | rsyslog | systemd journal | **HIGH** — log collection changes |
| **Cron** | crond | systemd timers | **MEDIUM** — cron jobs need migration |
| **Python** | 2.7 | 3 only | **HIGH** — Python 2 scripts break |
| **cgroups** | v1 | v2 (unified) | **MEDIUM** — container runtime config |
| **/tmp** | Disk-backed | tmpfs (RAM) | **MEDIUM** — large temp files affected |
| **EBS** | gp2 | gp3 | Low — cost savings |
| **Boot** | Legacy BIOS | UEFI + Secure Boot | Low |
| **Java** | OpenJDK | Amazon Corretto | Low |
| **AWS CLI** | v1 | v2 | Low — API compatible |
| **Compiler Triplet** | `*-redhat-linux-gcc` | `*-amazon-linux-gcc` | Low |
| **32-bit** | Limited runtime | Not supported | **HIGH** if using 32-bit |
| **lsb_release** | Available | Not available | Use `/etc/os-release` |
| **Desktop** | MATE | GNOME (2023.7+) | Low |
| **SELinux + cloud-init** | Not together | Supported | Improvement |
| **cloud-init errors** | Silent | **Fatal (fail closed)** | **HIGH** — review configs |

### ⚠️ Breaking Changes to Watch For

1. **cloud-init**: Unavailable remote resources now cause **fatal errors** (was silent in AL2)
2. **No auto security updates**: AL2023 does NOT install security updates via cloud-init by default
3. **Deterministic repos**: `dnf update` does nothing unless you specify a release version
4. **systemd-networkd**: All network config migrated — ISC dhclient scripts won't work
5. **systemd journal**: rsyslog-based log shipping needs reconfiguration
6. **systemd timers**: crontab entries need migration to .timer units

---

## 6. Networking

### systemd-networkd (AL2023)
AL2023 replaces ISC dhclient with systemd-networkd.

```bash
# List all interfaces
$ networkctl

# Show interface details
$ networkctl status ens5

# Check DNS
$ resolvectl
```

### amazon-ec2-net-utils v2.x
Pre-installed on AL2023 — handles VPC networking automatically:
- Per-interface policy routing
- Secondary IPv4 configuration
- ENI hotplug
- Delegated prefix routing
- Config stored in `/run/` (ephemeral, regenerated on boot)
- Custom overrides: `/etc/systemd/network/`

**Key principle**: Traffic routes via the ENI associated with the source address.

Repository: https://github.com/amazonlinux/amazon-ec2-net-utils

### Verification
```bash
$ networkctl                     # All physical interfaces should show "routable" + "configured"
$ networkctl status ens5         # Should reference /run/systemd/network/70-ens5.network
$ resolvectl                     # DNS resolver status
```

---

## 7. Container Images & Docker

### Image Sources

| Source | Image |
|--------|-------|
| **ECR Public** | `public.ecr.aws/amazonlinux/amazonlinux:2023` |
| **Docker Hub** | `amazonlinux:2023` |

### Docker Tags
- `2027` — AL2027 Preview
- `2023`, `latest` — AL2023 (recommended)
- `2` — AL2 (EOL Jun 2026)
- `2018.03`, `1` — AL1 (deprecated)

### Quick Start
```bash
# ECR login
$ aws ecr-public get-login-password --region us-east-1 \
    | docker login --username AWS --password-stdin public.ecr.aws

# Run AL2023 interactively
$ docker run --rm -it public.ecr.aws/amazonlinux/amazonlinux:2023 /bin/bash

# From Docker Hub
$ docker pull amazonlinux:2023
```

---

## 8. AMI Management & SSM

### SSM Parameter Aliases for AL2023

| Alias | Description |
|-------|-------------|
| `al2023-ami-kernel-default-x86_64` | Standard x86_64 |
| `al2023-ami-kernel-default-arm64` | Standard ARM64 |
| `al2023-ami-minimal-kernel-default-x86_64` | Minimal x86_64 |
| `al2023-ami-minimal-kernel-default-arm64` | Minimal ARM64 |

### Lookup & Launch
```bash
# Get latest AMI ID
$ aws ssm get-parameters \
    --region us-east-2 \
    --names /aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-arm64

# Launch with dynamic SSM resolution
$ aws ec2 run-instances \
    --image-id resolve:ssm:/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-arm64 \
    --instance-type c6g.medium \
    --key-name my_ssh_key
```

---

## 9. Security Best Practices

### AL2023 Security Features
- **System crypto policies**: Configure at launch/runtime for TLS versions, cipher suites
- **Kernel hardening**: Many features enabled by default
- **IMDSv2**: Required (HTTP tokens enforced)
- **UEFI Secure Boot**: Supported
- **SELinux**: Compatible with cloud-init

### Security Advisory Sources
| Version | URL |
|---------|-----|
| AL2027 | https://alas.aws.amazon.com/alas2027.html |
| AL2023 | https://alas.aws.amazon.com/alas2023.html |
| AL2 | https://alas.aws.amazon.com/alas2.html |

### Best Practices
1. Use deterministic updates — don't `dnf update` blindly
2. Enforce IMDSv2 (HttpTokens = required)
3. Use gp3 encrypted volumes
4. Monitor ALAS (Amazon Linux Security Advisories)
5. Use immutable infrastructure — rebuild AMIs, don't patch in-place
6. Run containers as non-root

---

## 10. Infrastructure as Code

### Terraform Key Pattern
```hcl
# Dynamic AMI lookup via SSM
data "aws_ssm_parameter" "al2023_ami" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

resource "aws_instance" "al2023" {
  ami           = data.aws_ssm_parameter.al2023_ami.value
  instance_type = "t3.micro"
  
  root_block_device {
    volume_type = "gp3"
    encrypted   = true
  }
  
  metadata_options {
    http_tokens = "required"  # IMDSv2
  }
}
```

### CloudFormation Key Pattern
```yaml
ImageId: '{{resolve:ssm:/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64}}'
```

---

## 11. Essential Commands Cheat Sheet

### System Info
```bash
uname -r                          # Kernel version
cat /etc/os-release               # OS details
hostnamectl                       # System info
```

### Package Management
```bash
dnf search <pkg>                  # Search
dnf install -y <pkg>              # Install
dnf remove <pkg>                  # Remove
dnf list installed                # List all
dnf check-release-update          # Check updates
dnf upgrade --releasever=X -y     # Upgrade
```

### Networking
```bash
networkctl                        # Interface list
networkctl status ens5            # Interface details
resolvectl                        # DNS status
ip addr show                      # IP addresses
```

### systemd Services
```bash
systemctl status <service>        # Service status
systemctl enable --now <service>  # Enable + start
systemctl --failed                # Failed services
journalctl -u <service> -f        # Follow logs
```

### EC2 Metadata (IMDSv2)
```bash
TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" \
    -H "X-aws-ec2-metadata-token-ttl-seconds: 60")

curl -s -H "X-aws-ec2-metadata-token: $TOKEN" \
    http://169.254.169.254/latest/meta-data/instance-type
```

---

## 12. Key Links & Resources

### Official Documentation
- [AL2023 User Guide](https://docs.aws.amazon.com/linux/al2023/ug/what-is-amazon-linux.html)
- [AL2027 User Guide](https://docs.aws.amazon.com/linux/al2027/ug/what-is-amazon-linux-2027.html)
- [Kernel Update Guide](https://docs.aws.amazon.com/linux/al2023/ug/kernel-update.html)
- [AL2 vs AL2023 Comparison](https://docs.aws.amazon.com/linux/al2023/ug/compare-with-al2.html)
- [AL2027 vs AL2023 Comparison](https://docs.aws.amazon.com/linux/al2027/ug/compare-with-al2023.html)

### Security
- [AL2023 Security Advisories (ALAS)](https://alas.aws.amazon.com/alas2023.html)
- [AL2027 Security Advisories](https://alas.aws.amazon.com/alas2027.html)

### Container Images
- [ECR Public Gallery](https://gallery.ecr.aws/amazonlinux/)
- [Container Images GitHub](https://github.com/amazonlinux/container-images)

### Community & Support
- [GitHub Issues (Container)](https://github.com/amazonlinux/container-images/issues)
- [GitHub Issues (AL2023)](https://github.com/amazonlinux/amazon-linux-2023/issues)
- [EC2 Net Utils](https://github.com/amazonlinux/amazon-ec2-net-utils)
- [AWS Forums](https://forums.aws.amazon.com/forum.jspa?forumID=228)
- [AWS Premium Support](https://aws.amazon.com/premiumsupport/)

### Blog Posts
- [AL2023 GA Announcement (Mar 2023)](https://aws.amazon.com/blogs/aws/amazon-linux-2023-a-cloud-optimized-linux-distribution-with-long-term-support/)

---

*Last updated: October 2026 | Not affiliated with AWS — community reference document*
