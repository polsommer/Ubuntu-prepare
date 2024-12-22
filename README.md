
# SWG Server Preparation Guide for Ubuntu

This guide will walk you through the process of setting up a **Star Wars Galaxies (SWG) Server** on Ubuntu. It has been updated to reflect a single server installation process using the customized scripts provided.

---

## Prerequisites

1. **Ubuntu Installation**:
   - Ensure you have a fresh installation of Ubuntu (20.04 LTS or newer is recommended).

2. **Static IP Configuration**:
   - Assign a static IP to your server. Use the network manager or update the `/etc/netplan/` configuration for static IP.

3. **Hostname**:
   - Set your hostname:
     ```bash
     sudo hostnamectl set-hostname swg
     ```
   - Update `/etc/hosts` to map your static IP and hostname:
     ```bash
     sudo nano /etc/hosts
     ```
     Add a line like:
     ```
     192.168.1.100 swg
     ```
     Save and exit (`Ctrl+O`, `Enter`, `Ctrl+X`).

4. **Reboot the System**:
   ```bash
   sudo reboot
   ```

---

## Installation Steps

### Step 1: Install Git and Clone the Repository
```bash
sudo apt update
sudo apt install git -y
git clone https://github.com/polsommer/Ubuntu-prepare.git
```

### Step 2: Prepare the Server
Run the main preparation script:
```bash
cd ~/swg-prepare
chmod +x *.sh
bash main.sh
```
You’ll see a menu. Select:
- **Single Server Install**

The script will handle the following:
- Install required dependencies.
- Configure Oracle Database.
- Set up the SWG server environment.

---

### Step 3: Oracle Database Setup
1. **Run Initialization**:
   - The script will automatically run `oinit.sh` to install prerequisites and configure the database.

2. **Run Oracle Installer**:
   - The `oracle_installer.sh` script sets up the Oracle database and runs the necessary root scripts.

3. **Create the Database**:
   - After the installation, the script will run `create_oracle_db.sh` to create the SWG database.

4. **Create SWG User**:
   - The SQL script `swgusr.sql` will set up the `swg` user with appropriate privileges and tablespace.

---

### Step 4: SWG Server Initialization
1. **Install SWG Dependencies**:
   - The `swginit.sh` script installs SWG-specific dependencies like `boost` and Oracle Instant Client.

2. **Download and Compile SWG Server**:
   ```bash
   git clone https://github.com/SWG-Source/swg-main.git ~/swg-main
   cd ~/swg-main
   ant swg
   ```

3. **Set Environment Variables**:
   - The script automatically sets up Oracle and Java paths in `/etc/profile.d/`.

---

### Step 5: Configure the SWG Server
1. Copy the configuration file:
   ```bash
   sudo cp ~/swg-prepare/servercommon.cfg ~/swg-main/exe/linux/servercommon.cfg
   ```

2. Start the Oracle Database service:
   ```bash
   sudo systemctl start odb.service
   ```

3. Start the SWG server:
   ```bash
   cd ~/swg-main/exe/linux
   ./swg-server
   ```

---

## Post-Installation Steps

### SQL Developer
To manage your Oracle database, install SQL Developer (optional):
```bash
sudo apt install sqldeveloper -y
/opt/sqldeveloper/sqldeveloper.sh
```

- Add a connection for `system`:
  - **Connection Name**: `system@swg`
  - **Username**: `system`
  - **Password**: `swg`
  - **SID**: `swg`

- Add another connection for `swg`:
  - **Connection Name**: `swg@swg`
  - **Username**: `swg`
  - **Password**: `swg`
  - **SID**: `swg`

---

## Maintenance and Tips

1. **Service Management**:
   - Start Oracle DB:
     ```bash
     sudo systemctl start odb.service
     ```
   - Stop Oracle DB:
     ```bash
     sudo systemctl stop odb.service
     ```

2. **Logs**:
   - Oracle Logs:
     ```bash
     sudo tail -f /u01/app/oracle/diag/rdbms/swg/swg/trace/alert_swg.log
     ```
   - SWG Server Logs:
     ```bash
     tail -f ~/swg-main/logs/*.log
     ```

3. **Updates**:
   - Keep your system up-to-date:
     ```bash
     sudo apt update && sudo apt upgrade -y
     ```

---

Congratulations! Your SWG server is now up and running on Ubuntu. For advanced configurations or troubleshooting, refer to the Oracle or SWG documentation. Let me know if further refinements are needed!
