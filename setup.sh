#!/bin/bash

# Main setup script
# Collects user inputs, saves to config file, and manages execution of steps

CONFIG_FILE="$(dirname "$0")/server-config.env"
STEP_LOG_FILE="$(dirname "$0")/completed-steps.log"

# Default values
MAINTENANCE_USER="bealers"
SITE_DOMAIN="bealers.com"
EMAIL="darren.beale@siftware.com"
PHP_VERSION="8.2"
REPO_URL="https://github.com/bealers/bealers.com.git"
DB_TYPE="sqlite"
REPO_ACCESS_TYPE="https"
USE_DEPLOY_KEY=false
DEPLOY_KEY_PATH=""

# Initialize step tracking
if [ ! -f "$STEP_LOG_FILE" ]; then
    touch "$STEP_LOG_FILE"
fi

# Function to check if a step is completed
is_step_completed() {
    grep -q "^$1:completed$" "$STEP_LOG_FILE" 2>/dev/null
    return $?
}

# Function to mark a step as completed
mark_step_completed() {
    if ! is_step_completed "$1"; then
        echo "$1:completed" >> "$STEP_LOG_FILE"
    fi
}

# Function to load configuration from file
load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        echo "Loading configuration from $CONFIG_FILE"
        source "$CONFIG_FILE"
        return 0
    else
        echo "No configuration file found. Will create a new one."
        return 1
    fi
}

# Function to save configuration to file
save_config() {
    echo "Saving configuration to $CONFIG_FILE"
    cat > "$CONFIG_FILE" << EOF
# Server Configuration - Generated on $(date)
MAINTENANCE_USER="$MAINTENANCE_USER"
SITE_DOMAIN="$SITE_DOMAIN"
EMAIL="$EMAIL"
PHP_VERSION="$PHP_VERSION"
REPO_URL="$REPO_URL"
DB_TYPE="$DB_TYPE"
REPO_ACCESS_TYPE="$REPO_ACCESS_TYPE"
USE_DEPLOY_KEY="$USE_DEPLOY_KEY"
DEPLOY_KEY_PATH="$DEPLOY_KEY_PATH"
EOF
}

# Function to gather user inputs
gather_inputs() {
    echo "==== Server Setup Configuration ===="
    
    read -p "Enter maintenance username (default: $MAINTENANCE_USER): " input
    MAINTENANCE_USER=${input:-$MAINTENANCE_USER}
    
    read -p "Enter site domain (default: $SITE_DOMAIN): " input
    SITE_DOMAIN=${input:-$SITE_DOMAIN}
    
    read -p "Enter email for SSL certificates (default: $EMAIL): " input
    EMAIL=${input:-$EMAIL}
    
    read -p "Enter PHP version (default: $PHP_VERSION): " input
    PHP_VERSION=${input:-$PHP_VERSION}
    
    # Repository configuration
    read -p "Enter Git repository URL (default: $REPO_URL): " input
    REPO_URL=${input:-$REPO_URL}
    
    # Ask about repository access method
    echo "How should we access the Git repository?"
    echo "1) HTTPS (default - may require credentials for private repos)"
    echo "2) SSH (uses SSH keys for authentication)"
    read -p "Enter choice [1-2]: " repo_choice
    if [[ $repo_choice == "2" ]]; then
        REPO_ACCESS_TYPE="ssh"
        
        # Convert HTTPS URL to SSH format if needed
        if [[ $REPO_URL == https://github.com/* ]]; then
            REPO_URL=${REPO_URL#https://github.com/}
            REPO_URL="git@github.com:${REPO_URL}"
        fi
        
        # Ask about deploy key 
        echo "Do you want to use a deploy key for the www-data user?"
        echo "1) No - Use maintenance user's SSH key (default)"
        echo "2) Yes - Use a dedicated deploy key"
        read -p "Enter choice [1-2]: " key_choice
        if [[ $key_choice == "2" ]]; then
            USE_DEPLOY_KEY=true
            
            echo "Choose deploy key option:"
            echo "1) Generate a new deploy key"
            echo "2) Provide an existing deploy key"
            read -p "Enter choice [1-2]: " deploy_key_choice
            
            if [[ $deploy_key_choice == "2" ]]; then
                read -p "Enter path to existing deploy key (private key): " DEPLOY_KEY_PATH
            fi
        fi
    fi
    
    echo "Select database type:"
    echo "1) MySQL (default)"
    echo "2) PostgreSQL"
    echo "3) SQLite"
    read -p "Enter choice [1-3]: " db_choice
    case $db_choice in
        2) DB_TYPE="pgsql" ;;
        3) DB_TYPE="sqlite" ;;
        *) DB_TYPE="mysql" ;;
    esac
    
    # Save the configuration
    save_config
    
    # Display summary
    echo -e "\n==== Configuration Summary ===="
    echo "Maintenance User: $MAINTENANCE_USER"
    echo "Site Domain: $SITE_DOMAIN"
    echo "Email: $EMAIL"
    echo "PHP Version: $PHP_VERSION"
    echo "Repository: $REPO_URL"
    echo "Repository Access: $REPO_ACCESS_TYPE"
    echo "Use Deploy Key: $USE_DEPLOY_KEY"
    if [ "$USE_DEPLOY_KEY" = true ] && [ -n "$DEPLOY_KEY_PATH" ]; then
        echo "Deploy Key Path: $DEPLOY_KEY_PATH"
    fi
    echo "Database Type: $DB_TYPE"
    echo "=============================="
    
    read -p "Proceed with this configuration? (Y/n): " confirm
    if [[ $confirm == "n" || $confirm == "N" ]]; then
        echo "Setup aborted."
        exit 1
    fi
}

# Function to run a specific step
run_step() {
    step_number="$1"
    step_name="$2"
    step_script="$(dirname "$0")/steps/$step_number-$step_name.sh"
    
    if [ ! -f "$step_script" ]; then
        echo "Error: Step script not found: $step_script"
        return 1
    fi
    
    if is_step_completed "$step_number-$step_name"; then
        echo "Step $step_number: $step_name - Already completed, skipping."
        return 0
    fi
    
    echo "==== Running Step $step_number: $step_name ===="
    chmod +x "$step_script"
    
    # Export all config variables for the script
    export MAINTENANCE_USER
    export SITE_DOMAIN
    export EMAIL
    export PHP_VERSION
    export REPO_URL
    export DB_TYPE
    export REPO_ACCESS_TYPE
    export USE_DEPLOY_KEY
    export DEPLOY_KEY_PATH
    
    # Run the step script
    "$step_script"
    step_exit_code=$?
    
    if [ $step_exit_code -eq 0 ]; then
        echo "Step $step_number: $step_name - Completed successfully."
        mark_step_completed "$step_number-$step_name"
        return 0
    else
        echo "Step $step_number: $step_name - Failed with exit code $step_exit_code."
        return $step_exit_code
    fi
}

# Function to run all steps
run_all_steps() {
    # Define all steps in order
    run_step "01" "system-basics" || return $?
    run_step "02" "security-baseline" || return $?
    run_step "03" "web-stack" || return $?
    run_step "04" "application-deploy" || return $?
    run_step "05" "advanced-hardening" || return $?
    
    echo "All steps completed successfully!"
    return 0
}

# Function to show usage help
show_help() {
    echo "Usage: $0 [options] [step]"
    echo ""
    echo "Options:"
    echo "  --help                Show this help message"
    echo "  --reconfigure         Run configuration wizard again"
    echo "  --list-steps          List all available steps"
    echo "  --run-from STEP       Run from a specific step onwards"
    echo "  --reset               Reset completion status for all steps"
    echo "  --reset-step STEP     Reset completion status for a specific step"
    echo ""
    echo "Steps:"
    echo "  01-system-basics      Set up users, SSH, timezone, and locale"
    echo "  02-security-baseline  Configure firewall and basic security"
    echo "  03-web-stack          Install and configure web server, PHP, database"
    echo "  04-application-deploy Deploy application code and dependencies"
    echo "  05-advanced-hardening Additional security measures and hardening"
    echo ""
    echo "Examples:"
    echo "  $0                   Run all steps (skipping completed ones)"
    echo "  $0 03-web-stack      Run only the web-stack step"
    echo "  $0 --reset           Reset all steps and start fresh"
}

# Function to list available steps
list_steps() {
    echo "Available steps:"
    echo "  01-system-basics      - Set up users, SSH, timezone, and locale"
    echo "  02-security-baseline  - Configure firewall and basic security"
    echo "  03-web-stack          - Install and configure web server, PHP, database"
    echo "  04-application-deploy - Deploy application code and dependencies"
    echo "  05-advanced-hardening - Additional security measures and hardening"
}

# Function to reset completion status for a specific step
reset_step() {
    step="$1"
    if [ -f "$STEP_LOG_FILE" ]; then
        sed -i "/^$step:completed$/d" "$STEP_LOG_FILE"
        echo "Reset completion status for step: $step"
    fi
}

# Function to reset all steps
reset_all_steps() {
    if [ -f "$STEP_LOG_FILE" ]; then
        rm "$STEP_LOG_FILE"
        touch "$STEP_LOG_FILE"
        echo "Reset completion status for all steps."
    fi
}

# Main script execution starts here

# Process command-line arguments
if [ $# -gt 0 ]; then
    case "$1" in
        --help)
            show_help
            exit 0
            ;;
        --reconfigure)
            gather_inputs
            ;;
        --list-steps)
            list_steps
            exit 0
            ;;
        --run-from)
            if [ -z "$2" ]; then
                echo "Error: Missing step name after --run-from"
                show_help
                exit 1
            fi
            # Reset all steps from the specified one onwards
            case "$2" in
                01-system-basics)
                    reset_step "01-system-basics"
                    reset_step "02-security-baseline"
                    reset_step "03-web-stack"
                    reset_step "04-application-deploy"
                    reset_step "05-advanced-hardening"
                    ;;
                02-security-baseline)
                    reset_step "02-security-baseline"
                    reset_step "03-web-stack"
                    reset_step "04-application-deploy"
                    reset_step "05-advanced-hardening"
                    ;;
                03-web-stack)
                    reset_step "03-web-stack"
                    reset_step "04-application-deploy"
                    reset_step "05-advanced-hardening"
                    ;;
                04-application-deploy)
                    reset_step "04-application-deploy"
                    reset_step "05-advanced-hardening"
                    ;;
                05-advanced-hardening)
                    reset_step "05-advanced-hardening"
                    ;;
                *)
                    echo "Error: Unknown step: $2"
                    list_steps
                    exit 1
                    ;;
            esac
            # Continue with running all steps (skipping completed ones)
            ;;
        --reset)
            reset_all_steps
            ;;
        --reset-step)
            if [ -z "$2" ]; then
                echo "Error: Missing step name after --reset-step"
                show_help
                exit 1
            fi
            reset_step "$2"
            exit 0
            ;;
        *)
            # Check if the argument is a valid step
            case "$1" in
                01-system-basics|02-security-baseline|03-web-stack|04-application-deploy|05-advanced-hardening)
                    load_config
                    step_name="${1#*-}"  # Remove the number prefix
                    step_number="${1%-*}" # Keep only the number
                    run_step "$step_number" "$step_name"
                    exit $?
                    ;;
                *)
                    echo "Error: Unknown option or step: $1"
                    show_help
                    exit 1
                    ;;
            esac
            ;;
    esac
fi

# Default execution path (no or unrecognized arguments)
if ! load_config; then
    # No configuration file found, so gather inputs
    gather_inputs
fi

# Run all steps (skipping completed ones)
run_all_steps
exit $?
