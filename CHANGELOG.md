# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased] - 2026-06-21

### Security Hardening (cyfence CIS Benchmark V3 Compliance)

#### Docker & Orchestration (`docker-compose.yml`)
- **Resource Limits**: Configured CPU and Memory limits for all containers (`web`, `php-fpm`, `db`, `redis`) to prevent DoS attacks.
- **Restart Policy**: Modified container restart policies from `always` to `"on-failure:5"` to mitigate endless crash-loop resource drain.
- **MariaDB Security**: Added database startup parameters `--local-infile=0`, `--skip-symbolic-links`, and `--secure-file-priv=/var/lib/mysql-files` to disable risky features and file exports.
- **Configuration Protection**: Mounted SSL keys, certificates, and OpenResty configuration files as read-only (`:ro`) to prevent modification by compromised worker processes.

#### Web Server (`openresty/config/nginx.conf`)
- **Worker Process Isolation**: Explicitly set Nginx workers to run under the unprivileged `www-data` user instead of root/default.
- **Access Logging**: Enabled access logs (`access_log logs/access.log main;`) for audits.
- **Slowloris Protection**: Reduced request/connection timeouts from `360s` to safer limits (`client_header_timeout 15`, `client_body_timeout 15`, `keepalive_timeout 60`).
- **DoS Protection**: Restricted maximum body upload size to `512M` (previously unlimited `0`) and lowered default header buffer configurations.
- **HTTP Method Restrictions**: Blocked dangerous HTTP methods (allowing only `GET`, `POST`, `HEAD`, `OPTIONS`, `PUT`, `DELETE`).
- **Brute-Force Rate Limiting**: Added a rate limit zone (`wp_login` at 2r/s, burst 5) specifically protecting `/wp-login.php` and `/xmlrpc.php`.

#### PHP-FPM Configuration (`php-fpm/config/php.ini`)
- **Version Masking**: Masked PHP version headers with `expose_php = Off`.
- **Dangerous Functions**: Disabled SUID/OS execution functions (`exec`, `shell_exec`, `passthru`, `system`, `proc_open`, `popen`, `show_source`, `symlink`).
- **Directory Traversal Prevention**: Confined file system access using `open_basedir = /var/www/html:/tmp`.
- **Remote File Inclusion (RFI)**: Disabled remote file inclusion with `allow_url_include = Off`.
- **Session Cookie Hardening**: Added secure session flags (`session.cookie_httponly = 1`, `session.cookie_secure = 1`, `session.cookie_samesite = Lax`, `session.use_strict_mode = 1`).

### Automation & Installation (`install.sh`)
- **Automated Configuration**: Added logic to automatically create `wp-config.php` from `wp-config-sample.php` during initial installation.
- **Database Connection Setup**: Automatically configures the database host to `db`, database name, user, and password parameters dynamically based on user input.
- **Table Prefix Customization**: Modified default database table prefix from `wp_` to `wpx_` in `wp-config.php`.
- **Robust Redis Config Append**: Wrapped Redis settings injection in existence checks to avoid installer errors on subsequent runs.
