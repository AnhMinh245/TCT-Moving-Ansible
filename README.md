# DỰ ÁN TCT_36_MOVINGDC_2024 BỔ SUNG MÁY CHỦ DATABASE HDDT TẠI DRC TỰ ĐỘNG HÓA CÀI ĐẶT VỚI ANSIBLE

## Mục lục

### Thành phần

### Hướng dẫn cài đặt

### Các package cần cài đặt

```bash
ansible-galaxy collection install ansible.posix
ansible-galaxy collection install community.general
```

### Hướng dẫn sử dụng

## Các phần đã chạy thử

```bash
#ROLES
roles/common/tasks/
roles/configure_system_limits/
roles/os_hardening/

#PLAYBOOKS
playbooks/common.yml


```

## Các phần chưa chạy thử

- Role và playbook Repository
- Role install_common_tools do chưa có repo
- Role và playbooks users-groups