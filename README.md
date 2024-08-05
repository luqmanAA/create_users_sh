# User and Group Management Script

## Introduction

In the world of system administration and automation, creating user accounts on a Linux system is a frequent yet crucial task. Automating this process enhances efficiency, consistency, and security. This README provides a detailed explanation of a Bash script, `create_users.sh`, designed to automate user and group management. The script reads user information from a file, generates random passwords, creates users and groups, and logs actions, making it a powerful tool for system administrators.

## Prerequisites

Before using the script, ensure you have the following:
- Basic understanding of the Bash shell.
- Superuser (root) privileges on your Linux system.
- A text file containing usernames and group names in the format `user;groups` (e.g., `alice;admins,dev`).

## The Bash Script

```bash
#!/bin/bash

# Script: create_users.sh
# Description: Creates users and assigns them to specified groups.
# Logs all actions to /var/log/user_management.log and stores passwords in /var/secure/user_passwords.txt.

# Log file
LOGFILE="/var/log/user_management.log"
# Password file
PASSWORD_FILE="/var/secure/user_passwords.txt"

# Create the secure directory if it doesn't exist
mkdir -p /var/secure
chmod 700 /var/secure

# Function to log messages
log_message() {
    local message="$1"
    echo "$(date +'%Y-%m-%d %H:%M:%S') - $message" | tee -a $LOGFILE
}

# Function to generate random passwords
generate_password() {
    local password=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 12)
    echo "$password"
}

# Check if a file was provided as argument
if [ -z "$1" ]; then
    log_message "Error: No input file provided."
    exit 1
fi

# Read the input file line by line
while IFS=';' read -r user groups; do
    user=$(echo $user | xargs) # trim whitespace
    groups=$(echo $groups | xargs) # trim whitespace

    # Check if the user already exists
    if id -u "$user" >/dev/null 2>&1; then
        log_message "User $user already exists. Skipping creation."
        continue
    fi

    # Create personal group for the user
    log_message "Creating group $user."
    groupadd "$user"

    # Create the user with the personal group
    log_message "Creating user $user."
    password=$(generate_password)
    useradd -m -g "$user" -s /bin/bash -p $(echo "$password" | openssl passwd -1 -stdin) "$user"
    if [ $? -eq 0 ]; then
        log_message "User $user created successfully."
        echo "$user:$password" >> $PASSWORD_FILE
        chmod 600 $PASSWORD_FILE
    else
        log_message "Error creating user $user."
        continue
    fi

    # Assign additional groups to the user
    IFS=',' read -ra ADDR <<< "$groups"
    for group in "${ADDR[@]}"; do
        group=$(echo $group | xargs) # trim whitespace

        if [ -n "$group" ]; then
            # Create the group if it doesn't exist
            if ! getent group "$group" >/dev/null; then
                log_message "Creating group $group."
                groupadd "$group"
            fi
            log_message "Adding user $user to group $group."
            usermod -aG "$group" "$user"
        fi
    done
done < "$1"

log_message "User creation process completed."

exit 0
```

## Understanding the Script
### Shebang 
The script begins with #!/bin/bash, which indicates that it should be interpreted using the Bash shell.

### Logging and Password Files
Log File: The script logs all actions to /var/log/user_management.log for auditing and troubleshooting.
Password File: The generated passwords are stored securely in /var/secure/user_passwords.txt.

### Functions
log_message: Logs messages with timestamps to both the log file and the console.
generate_password: Generates a random 12-character password using /dev/urandom.

### Main Execution
Input Check: Validates that an input file is provided.
Read and Process File: Reads each line of the input file, extracts the username and group names, and performs user and group creation.
User and Group Handling: Creates a personal group for each user, generates a random password, and assigns additional groups as specified in the input file.

### Running the Script
Ensure Executable Permissions: Before running the script, make sure it has executable permissions:

```bash
chmod +x create_users.sh
```

Execute the Script: Run the script with the input file as an argument, using superuser privileges:
```bash
sudo ./create_users.sh users.txt
```

Review Logs: Check /var/log/user_management.log for details about the script’s execution.

Secure Passwords: Verify the generated passwords in /var/secure/user_passwords.txt.
