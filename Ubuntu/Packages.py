import os
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

def install_deb_packages(deb_files):
    success_list = []
    failure_list = []

    for deb_file in deb_files:
        deb_filename = os.path.basename(deb_file)
        simulate_progress(f"Installing {deb_filename}")
        success, message = run_command(['sudo', 'dpkg', '-i', deb_file])
        if success:
            print(f"Installing {deb_filename} completed.\n")
            success_list.append(deb_filename)
        else:
            dependencies = extract_dependencies(message)
            if dependencies:
                print(f"Missing dependencies for {deb_filename}: {', '.join(dependencies)}")
                choice = input("Do you want to install these dependencies? (y/n): ")
                if choice.lower() == 'y':
                    install_dependencies(dependencies)
                    # Retry the installation after dependencies are resolved
                    simulate_progress(f"Reinstalling {deb_filename}")
                    success, message = run_command(['sudo', 'dpkg', '-i', deb_file])
                    if success:
                        print(f"Reinstalling {deb_filename} completed.\n")
                        success_list.append(deb_filename)
                    else:
                        print(f"Reinstalling {deb_filename} failed.\n")
                        failure_list.append((deb_filename, "Failed after dependency installation"))
                else:
                    print("User opted not to install dependencies.")
                    failure_list.append((deb_filename, "Dependency installation declined by user"))
            else:
                failure_list.append((deb_filename, "Dependency issues, but unable to parse dependencies."))

    print("\nDEB Package Installation Summary:")
    if success_list:
        print("Successfully installed DEB packages:")
        for idx, package in enumerate(success_list, 1):
            print(f"{idx}. {package}")

    if failure_list:
        print("\nUnsuccessful DEB installations:")
        for idx, (package, reason) in enumerate(failure_list, 1):
            print(f"{idx}. {package}: {reason}")

def extract_dependencies(dpkg_message):
    # This function needs to parse the dpkg error message to find missing dependencies
    lines = dpkg_message.split('\n')
    dependencies = []
    for line in lines:
        if 'depends on' in line:
            parts = line.split('depends on')[1].split(';')[0].strip().split(',')
            for part in parts:
                dep = part.strip().split()[0]  # Only take the package name
                if dep not in dependencies:
                    dependencies.append(dep)
    return dependencies

def install_dependencies(dependencies):
    for dep in dependencies:
        success, message = run_command(['sudo', 'apt', 'install', '-y', dep])
        if success:
            print(f"Installing dependency {dep} completed.\n")
        else:
            print(f"Installing dependency {dep} failed.\n")

def show_deb_package_menu():
    deb_dir = os.path.join(os.getcwd(), "DEB")
    while True:
        if not os.path.exists(deb_dir):
            os.makedirs(deb_dir)

        deb_files = [f for f in os.listdir(deb_dir) if f.endswith('.deb')]
        deb_files.sort()

        if not deb_files:
            print("\033[91mPlease add DEB files in the DEB directory, then press 'Refresh'.\033[0m")
            print("1. Refresh")
            print("2. Back")
        else:
            print("\nAvailable DEB packages:")
            for idx, deb_file in enumerate(deb_files, start=1):
                print(f"{idx}. {deb_file}")

            print(f"{len(deb_files) + 1}. Install All")
            print(f"{len(deb_files) + 2}. Back")
            print("\nNote: To install multiple DEB packages, enter their numbers separated by commas (e.g., 1,2)")

        choice = input("Enter your choice: ")

        if choice.isdigit():
            choice = int(choice)
            if 1 <= choice <= len(deb_files):
                deb_files_full_path = [os.path.join(deb_dir, deb_files[choice - 1])]
                install_deb_packages(deb_files_full_path)
            elif choice == len(deb_files) + 1:
                install_deb_packages([os.path.join(deb_dir, f) for f in deb_files])
            elif choice == len(deb_files) + 2:
                return
        elif ',' in choice:
            try:
                indices = [int(i) - 1 for i in choice.split(',')]
                selected_deb_files = [os.path.join(deb_dir, deb_files[i]) for i in indices if 0 <= i < len(deb_files)]
                install_deb_packages(selected_deb_files)
            except ValueError:
                print("Invalid input. Please enter numbers separated by commas.")
        else:
            print("Invalid choice!")

def check_termcolor():
    try:
        import termcolor
        return True
    except ImportError:
        return False

def install_termcolor():
    print("The 'termcolor' package is required for this menu.")
    choice = input("Do you want to install 'termcolor'? (y/n): ")
    if choice.lower() == 'y':
        success, message = run_command(['pip3', 'install', 'termcolor'])
        if success:
            print("The 'termcolor' package has been installed.")
            return True
        else:
            print(f"Failed to install 'termcolor': {message}")
            return False
    else:
        return False

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
        print("7. Advanced")
        print("8. Back")

        choice = input("Enter your choice (1-8): ")

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
            if check_termcolor():
                show_deb_package_menu()
            else:
                if install_termcolor():
                    show_deb_package_menu()
                else:
                    print("Returning to the main menu...")
        elif choice == '8':
            print("Returning to the main menu...")
            return
        else:
            print("Invalid choice. Please try again.")

if __name__ == "__main__":
    main()
