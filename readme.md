# Odoo 17 Installation Guide

I tried to install odoo 17 in hostinger VPS of ubuntu 20.04, 22.04 and 24.04 but failed to install, Then I write the following script and it works. So I think it will also work on contabo or other vps also.



## **Installation Steps**

Follow these three simple steps to install Odoo 17:

### **Step 1: Download the Installation Script**
Use `wget` to download the installation script from GitHub.

```bash
sudo wget https://raw.githubusercontent.com/sattar-kuet/Odoo-17-Installation-Script/refs/heads/main/odoo17_installationscript.sh
```
### **Step 2: change params like domain, config file name, service name**
```bash
sudo nano odoo17_installationscript.sh
```

### **Step 3: Grant Execution Permission**
Make the downloaded script executable.

```bash
sudo chmod +x odoo17_installationscript.sh
```

### **Step 4: Run the Installation Script**
Execute the script to begin the installation process.

```bash
sudo ./odoo17_installationscript.sh
```

