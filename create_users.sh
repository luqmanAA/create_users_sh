#!/bin/bash


# Log file
LOGFILE="/var/log/user_management.log"
# Password file
PASSWORD_FILE="/var/secure/user_passwords.csv"

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
    local password=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 16)
    echo "$password"
}

# valid file argument
if [ -z "$1" ]; then
    log_message "Error: No file provided."
    exit 1
fi

# Read the input file line by line
while IFS=';' read -r user groups; do
    user=$(echo $user | xargs)
    groups=$(echo $groups | xargs) 

    # validate user already exists
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
        group=$(echo $group | xargs)

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
