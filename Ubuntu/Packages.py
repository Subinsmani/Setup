import subprocess
import time

def run_command(command):
    try:
        process = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.PIPE, universal_newlines=True)
        stdout, stderr = process.communicate()
        if process.returncode != 0:
            return (False, stderr.strip())
        return (True, stdout.strip())
    except subprocess.CalledProcessError as e:
        return (False, str(e))

def print_progress_bar(progress, description):
    bar_length = 20
    block = int(round(bar_length * progress / 100))
    text = f"\r{description} [{'■' * block + '□' * (bar_length - block)}] {progress}%"
    print(text, end='', flush=True)

def simulate_progress(description):
    stages = [10, 20, 30, 40, 50, 60, 70, 80, 90, 100]
    for progress in stages:
        print_progress_bar(progress, description)
        time.sleep(0.5)
    print(f"\n")

def install_packages(package_list):
    run_command(['sudo', 'apt', 'update'])
    run_command(['sudo', 'apt', 'upgrade', '-y'])
    
    for package in package_list:
        simulate_progress(f"Installing {package}")
        run_command(['sudo', 'apt', 'install', '-y', package])

def uninstall_packages(package_list):
    for package in package_list:
        simulate_progress(f"Uninstalling {package}")
        run_command(['sudo', 'apt', 'remove', '-y', package])
    
    run_command(['sudo', 'apt', 'autoremove', '-y'])

def install_custom_packages(packages):
    run_command(['sudo', 'apt', 'update'])
    run_command(['sudo', 'apt', 'upgrade', '-y'])

    success_list = []
    failure_list = []

    for package in packages:
        simulate_progress(f"Installing {package}")
        success, message = run_command(['sudo', 'apt', 'install', '-y', package])
        if success:
            print(f"Installing {package} completed.\n")
            success_list.append(package)
        else:
            print(f"Installing {package} failed.\n")
            if "Unable to locate package" in message:
                reason = "Package not found"
            elif "already installed" in message:
                reason = "Package already installed"
            else:
                reason = message
            failure_list.append((package, reason))

    print("\nCustom Package Installation Summary:")
    if success_list:
        print("Successfully installed packages:")
        for idx, package in enumerate(success_list, 1):
            print(f"{idx}. {package}")

    if failure_list:
        print("\nUnsuccessful installations:")
        for idx, (package, reason) in enumerate(failure_list, 1):
            print(f"{idx}. {package}: {reason}")

def show_package_menu(category, packages):
    while True:
        print(f"\n{category} Packages: {', '.join(packages)}")
        print("1. Install All")
        print("2. Uninstall All")
        print("3. Back")

        choice = input("Enter your choice (1-3): ")

        if choice == '1':
            install_packages(packages)
        elif choice == '2':
            uninstall_packages(packages)
        elif choice == '3':
            return
        else:
            print("Invalid choice!")

def main():
    while True:
        print("\nSelect the type of packages to manage:")
        print("1. Package Management")
        print("2. System Utilities")
        print("3. Development Tools")
        print("4. Automation")
        print("5. Monitoring")
        print("6. Custom Package Installation")
        print("7. Back")
        
        choice = input("Enter your choice (1-7): ")
        
        if choice == '1':
            packages = ["python3-pip", "virtualenv"]
            show_package_menu("Package Management", packages)
        elif choice == '2':
            packages = ["htop", "ncdu", "curl", "wget"]
            show_package_menu("System Utilities", packages)
        elif choice == '3':
            packages = ["git", "docker.io", "code"]
            show_package_menu("Development Tools", packages)
        elif choice == '4':
            packages = ["ansible", "cron"]
            show_package_menu("Automation", packages)
        elif choice == '5':
            packages = ["netdata"]
            show_package_menu("Monitoring", packages)
        elif choice == '6':
            custom_packages = input("Enter the packages you want to install (space-separated): ")
            packages = custom_packages.split()
            install_custom_packages(packages)
        elif choice == '7':
            print("Returning to the main menu...")
            return
        else:
            print("Invalid choice. Please try again.")

if __name__ == "__main__":
    main()
