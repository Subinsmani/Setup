import subprocess

def install_packages():
    print("You can install multiple packages. Example: ssh, nano, tmux")
    packages = input("Enter the packages you want to install (comma-separated): ")
    package_list = [pkg.strip() for pkg in packages.split(',') if pkg.strip()]

    if not package_list:
        print("No packages specified for installation.")
        return

    print("Updating package list...")
    subprocess.run(['sudo', 'apt', 'update'], check=True)
    print("Upgrading existing packages...")
    subprocess.run(['sudo', 'apt', 'upgrade', '-y'], check=True)

    print(f"Installing selected packages: {', '.join(package_list)}")
    subprocess.run(['sudo', 'apt', 'install', '-y'] + package_list, check=True)

    print("Package installation complete!")

if __name__ == "__main__":
    install_packages()
