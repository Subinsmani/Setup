import os
import subprocess
import getpass
import shutil
import sys

def create_user():
    while True:
        print("\nSelect the type of user:")
        print("1. Administrator")
        print("2. Standard user")
        print("3. Back")
        user_type = input("Enter your choice (1/2/3): ")

        if user_type == '1':
            is_admin = True
        elif user_type == '2':
            is_admin = False
        elif user_type == '3':
            return
        else:
            print("Invalid choice! Please enter a valid option.")
            continue

        username = input("Enter username: ")
        first_name = input("Enter first name: ")
        last_name = input("Enter last name: ")

        while True:
            print("\nSelect authentication method:")
            print("1. Password")
            print("2. RSA with passphrase")
            print("3. Generate RSA (passwordless)")
            print("4. Back")
            auth_method = input("Enter your choice (1/2/3/4): ")

            if auth_method == '1':
                password = getpass.getpass("Enter password: ")
                confirm_password = getpass.getpass("Confirm password: ")
                if password != confirm_password:
                    print("Passwords do not match! Please try again.")
                    continue
                try:
                    # Create the user with /bin/bash as the default shell
                    subprocess.run(['sudo', 'useradd', '-m', '-s', '/bin/bash', '-c', f"{first_name} {last_name}", username], check=True)
                    subprocess.run(['sudo', 'chpasswd'], input=f"{username}:{password}".encode(), check=True)
                    if is_admin:
                        subprocess.run(['sudo', 'usermod', '-aG', 'sudo', username], check=True)

                    # Copy default files from /etc/skel to the user's home directory
                    home_dir = f"/home/{username}"
                    subprocess.run(['sudo', 'cp', '-r', '/etc/skel/.', home_dir], check=True)
                    subprocess.run(['sudo', 'chown', '-R', f"{username}:{username}", home_dir], check=True)

                    print(f"User {username} created with password authentication.")
                except subprocess.CalledProcessError as e:
                    print(f"Error creating user: {e}")
                break

            elif auth_method == '2':
                rsa_key = None
                while True:
                    print(f"\nSelect RSA key source (passphrase):")
                    print("1. Launchpad")
                    print("2. Github")
                    print("3. Generate")
                    print("4. Back")
                    rsa_source = input("Enter your choice (1/2/3/4): ")

                    if rsa_source == '1':
                        rsa_key = fetch_rsa_key('launchpad')
                    elif rsa_source == '2':
                        rsa_key = fetch_rsa_key('github')
                    elif rsa_source == '3':
                        rsa_key = generate_rsa_key(username, passphrase=True)
                    elif rsa_source == '4':
                        break
                    else:
                        print("Invalid choice! Please enter a valid option.")
                        continue

                    if rsa_key:
                        if rsa_key.startswith("<!DOCTYPE html>") or "Error: Page not found" in rsa_key:
                            print("Invalid username or RSA key not found. Please try again.")
                            continue

                        print(f"Fetched RSA key: {rsa_key}")
                        try:
                            # Create the user with /bin/bash as the default shell
                            subprocess.run(['sudo', 'useradd', '-m', '-s', '/bin/bash', '-c', f"{first_name} {last_name}", username], check=True)
                            home_dir = f"/home/{username}"
                            ssh_dir = os.path.join(home_dir, '.ssh')
                            os.makedirs(ssh_dir, exist_ok=True)
                            auth_keys_file = os.path.join(ssh_dir, 'authorized_keys')

                            with open(auth_keys_file, 'w') as auth_file:
                                auth_file.write(rsa_key)
                            subprocess.run(['sudo', 'chown', '-R', f"{username}:{username}", ssh_dir], check=True)
                            subprocess.run(['sudo', 'chmod', '700', ssh_dir], check=True)
                            subprocess.run(['sudo', 'chmod', '600', auth_keys_file], check=True)
                            if is_admin:
                                subprocess.run(['sudo', 'usermod', '-aG', 'sudo', username], check=True)

                            # Copy default files from /etc/skel to the user's home directory
                            subprocess.run(['sudo', 'cp', '-r', '/etc/skel/.', home_dir], check=True)
                            subprocess.run(['sudo', 'chown', '-R', f"{username}:{username}", home_dir], check=True)

                            print(f"User {username} created with RSA authentication.")
                            print(f"RSA key added to {auth_keys_file}.")
                        except subprocess.CalledProcessError as e:
                            print(f"Error creating user: {e}")
                        break
                    else:
                        print("Failed to fetch RSA key. Please try again.")
                break

            elif auth_method == '3':
                rsa_key = generate_rsa_key(username, passphrase=False)
                if rsa_key:
                    try:
                        # Create the user with /bin/bash as the default shell
                        subprocess.run(['sudo', 'useradd', '-m', '-s', '/bin/bash', '-c', f"{first_name} {last_name}", username], check=True)
                        home_dir = f"/home/{username}"
                        ssh_dir = os.path.join(home_dir, '.ssh')
                        os.makedirs(ssh_dir, exist_ok=True)
                        auth_keys_file = os.path.join(ssh_dir, 'authorized_keys')

                        temp_key_path = f"/tmp/{username}_rsa_key"
                        temp_pub_key_path = f"{temp_key_path}.pub"
                        with open(auth_keys_file, 'w') as auth_file:
                            auth_file.write(rsa_key)
                        shutil.move(temp_key_path, os.path.join(ssh_dir, 'id_rsa'))
                        shutil.move(temp_pub_key_path, os.path.join(ssh_dir, 'id_rsa.pub'))
                        subprocess.run(['sudo', 'chown', '-R', f"{username}:{username}", ssh_dir], check=True)
                        subprocess.run(['sudo', 'chmod', '700', ssh_dir], check=True)
                        subprocess.run(['sudo', 'chmod', '600', os.path.join(ssh_dir, 'id_rsa')], check=True)
                        subprocess.run(['sudo', 'chmod', '644', os.path.join(ssh_dir, 'id_rsa.pub')], check=True)
                        subprocess.run(['sudo', 'chmod', '600', auth_keys_file], check=True)
                        if is_admin:
                            subprocess.run(['sudo', 'usermod', '-aG', 'sudo', username], check=True)

                        # Copy default files from /etc/skel to the user's home directory
                        subprocess.run(['sudo', 'cp', '-r', '/etc/skel/.', home_dir], check=True)
                        subprocess.run(['sudo', 'chown', '-R', f"{username}:{username}", home_dir], check=True)

                        print(f"User {username} created with RSA authentication.")
                        print(f"RSA key added to {auth_keys_file}.")
                    except subprocess.CalledProcessError as e:
                        print(f"Error creating user: {e}")
                else:
                    print("Failed to generate RSA key. Please try again.")
                break

            elif auth_method == '4':
                break
            else:
                print("Invalid choice! Please enter a valid option.")
                continue

        break

def delete_user():
    username = input("Enter username to delete: ")
    if not user_exists(username):
        print(f"User {username} does not exist.")
        return

    try:
        # Attempt to kill all processes owned by the user
        subprocess.run(['sudo', 'pkill', '-u', username], check=True)
    except subprocess.CalledProcessError:
        print(f"Warning: Could not kill all processes owned by {username}. Proceeding with forceful deletion.")
        try:
            # Forcefully kill all processes owned by the user
            subprocess.run(['sudo', 'pkill', '-9', '-u', username], check=True)
        except subprocess.CalledProcessError:
            print(f"Warning: Forceful process termination for {username} also failed. Proceeding with user deletion.")

    try:
        # Delete the user
        subprocess.run(['sudo', 'userdel', '-r', username], check=True)
        print(f"User {username} deleted.")
    except subprocess.CalledProcessError as e:
        print(f"Error deleting user: {e}")

def manage_user():
    username = input("Enter username to manage: ")
    if not user_exists(username):
        print(f"User {username} does not exist.")
        return

    while True:
        print("\nManage user:")
        print("1. Change username")
        print("2. Change password")
        print("3. Change RSA key")
        print("4. Back")
        choice = input("Enter your choice (1/2/3/4): ")

        if choice == '1':
            old_username = username
            new_username = input("Enter new username: ")
            try:
                subprocess.run(['sudo', 'usermod', '-l', new_username, old_username], check=True)
                subprocess.run(['sudo', 'usermod', '-d', f"/home/{new_username}", '-m', new_username], check=True)
                move_data = input("Do you want to move old user data to new user? (yes/no): ")
                if move_data.lower() == 'yes':
                    subprocess.run(['sudo', 'mv', f"/home/{old_username}", f"/home/{new_username}"], check=True)
                    subprocess.run(['sudo', 'chown', '-R', f"{new_username}:{new_username}", f"/home/{new_username}"], check=True)
                print(f"Username changed from {old_username} to {new_username}.")
            except subprocess.CalledProcessError as e:
                print(f"Error changing username: {e}")
            break

        elif choice == '2':
            password = getpass.getpass("Enter new password: ")
            confirm_password = getpass.getpass("Confirm new password: ")
            if password != confirm_password:
                print("Passwords do not match! Please try again.")
                continue
            try:
                # Using subprocess to handle the password change
                process = subprocess.Popen(['sudo', 'passwd', username], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
                stdout, stderr = process.communicate(input=f"{password}\n{password}\n".encode())
                if process.returncode != 0:
                    print(f"Error changing password: {stderr.decode().strip()}")
                else:
                    print(f"Password for user {username} changed.")
            except subprocess.CalledProcessError as e:
                print(f"Error changing password: {e}")
            break

        elif choice == '3':
            while True:
                print("\nSelect new authentication method:")
                print("1. Password")
                print("2. RSA with passphrase")
                print("3. Generate RSA (passwordless)")
                print("4. Back")
                auth_method = input("Enter your choice (1/2/3/4): ")

                if auth_method == '1':
                    password = getpass.getpass("Enter new password: ")
                    confirm_password = getpass.getpass("Confirm new password: ")
                    if password != confirm_password:
                        print("Passwords do not match! Please try again.")
                        continue
                    try:
                        process = subprocess.Popen(['sudo', 'passwd', username], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
                        stdout, stderr = process.communicate(input=f"{password}\n{password}\n".encode())
                        if process.returncode != 0:
                            print(f"Error changing password: {stderr.decode().strip()}")
                        else:
                            print(f"Password for user {username} changed.")
                    except subprocess.CalledProcessError as e:
                        print(f"Error changing password: {e}")
                    break

                elif auth_method == '2':
                    rsa_key = None
                    while True:
                        print(f"\nSelect RSA key source (passphrase):")
                        print("1. Launchpad")
                        print("2. Github")
                        print("3. Generate")
                        print("4. Back")
                        rsa_source = input("Enter your choice (1/2/3/4): ")

                        if rsa_source == '1':
                            rsa_key = fetch_rsa_key('launchpad')
                        elif rsa_source == '2':
                            rsa_key = fetch_rsa_key('github')
                        elif rsa_source == '3':
                            rsa_key = generate_rsa_key(username, passphrase=True)
                        elif rsa_source == '4':
                            break
                        else:
                            print("Invalid choice! Please enter a valid option.")
                            continue

                        if rsa_key:
                            if rsa_key.startswith("<!DOCTYPE html>") or "Error: Page not found" in rsa_key:
                                print("Invalid username or RSA key not found. Please try again.")
                                continue

                            print(f"Fetched RSA key: {rsa_key}")
                            try:
                                home_dir = f"/home/{username}"
                                ssh_dir = os.path.join(home_dir, '.ssh')
                                os.makedirs(ssh_dir, exist_ok=True)
                                auth_keys_file = os.path.join(ssh_dir, 'authorized_keys')

                                with open(auth_keys_file, 'w') as auth_file:
                                    auth_file.write(rsa_key)
                                subprocess.run(['sudo', 'chown', '-R', f"{username}:{username}", ssh_dir], check=True)
                                subprocess.run(['sudo', 'chmod', '700', ssh_dir], check=True)
                                subprocess.run(['sudo', 'chmod', '600', auth_keys_file], check=True)
                                print(f"RSA key for user {username} changed.")
                                print(f"RSA key added to {auth_keys_file}.")
                            except subprocess.CalledProcessError as e:
                                print(f"Error changing RSA key: {e}")
                            break
                        else:
                            print("Failed to fetch RSA key. Please try again.")
                    break

                elif auth_method == '3':
                    rsa_key = generate_rsa_key(username, passphrase=False)
                    if rsa_key:
                        try:
                            home_dir = f"/home/{username}"
                            ssh_dir = os.path.join(home_dir, '.ssh')
                            os.makedirs(ssh_dir, exist_ok=True)
                            auth_keys_file = os.path.join(ssh_dir, 'authorized_keys')

                            temp_key_path = f"/tmp/{username}_rsa_key"
                            temp_pub_key_path = f"{temp_key_path}.pub"
                            with open(auth_keys_file, 'w') as auth_file:
                                auth_file.write(rsa_key)
                            shutil.move(temp_key_path, os.path.join(ssh_dir, 'id_rsa'))
                            shutil.move(temp_pub_key_path, os.path.join(ssh_dir, 'id_rsa.pub'))
                            subprocess.run(['sudo', 'chown', '-R', f"{username}:{username}", ssh_dir], check=True)
                            subprocess.run(['sudo', 'chmod', '700', ssh_dir], check=True)
                            subprocess.run(['sudo', 'chmod', '600', os.path.join(ssh_dir, 'id_rsa')], check=True)
                            subprocess.run(['sudo', 'chmod', '644', os.path.join(ssh_dir, 'id_rsa.pub')], check=True)
                            subprocess.run(['sudo', 'chmod', '600', auth_keys_file], check=True)
                            print(f"RSA key for user {username} changed.")
                            print(f"RSA key added to {auth_keys_file}.")
                        except subprocess.CalledProcessError as e:
                            print(f"Error changing RSA key: {e}")
                    else:
                        print("Failed to generate RSA key. Please try again.")
                    break

                elif auth_method == '4':
                    break
                else:
                    print("Invalid choice! Please enter a valid option.")
                    continue
            break

        elif choice == '4':
            break

        else:
            print("Invalid choice! Please enter a valid option.")
            continue

def user_exists(username):
    try:
        subprocess.run(['id', username], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        return True
    except subprocess.CalledProcessError:
        return False

def fetch_rsa_key(source):
    if source == 'launchpad':
        launchpad_username = input("Enter Launchpad username: ").lower()
        url = f"https://launchpad.net/~{launchpad_username}/+sshkeys"
    elif source == 'github':
        github_username = input("Enter GitHub username: ").lower()
        url = f"https://github.com/{github_username}.keys"
    else:
        return None

    rsa_key = get_rsa_from_url(url)
    if rsa_key:
        return rsa_key.strip()
    return None

def get_rsa_from_url(url):
    try:
        print(f"Fetching RSA key from {url}")
        rsa_key = subprocess.check_output(['curl', '-s', url], universal_newlines=True)
        if rsa_key.startswith("<!DOCTYPE html>") or "Error: Page not found" in rsa_key:
            return None
        print(f"Fetched RSA key: {rsa_key}")
        return rsa_key
    except subprocess.CalledProcessError as e:
        print(f"Error fetching RSA key from {url}: {e}")
        return None

def generate_rsa_key(username, passphrase=True):
    key_path = f'/tmp/{username}_rsa_key'
    pub_key_path = f"{key_path}.pub"
    try:
        if passphrase:
            passphrase = getpass.getpass("Enter passphrase: ")
            if not passphrase:
                print("Passphrase cannot be empty.")
                return None
            subprocess.run(['ssh-keygen', '-t', 'rsa', '-f', key_path, '-N', passphrase], check=True)
        else:
            subprocess.run(['ssh-keygen', '-t', 'rsa', '-f', key_path, '-N', ''], check=True)
        with open(pub_key_path, 'r') as key_file:
            rsa_key = key_file.read().strip()
        return rsa_key
    except subprocess.CalledProcessError as e:
        print(f"Error generating RSA key: {e}")
        return None

def user_tool():
    while True:
        print("\nUser tool:")
        print("1. Create user")
        print("2. Delete user")
        print("3. Manage user")
        print("4. Back")
        choice = input("Enter your choice (1/2/3/4): ")

        if choice == '1':
            create_user()
        elif choice == '2':
            delete_user()
        elif choice == '3':
            manage_user()
        elif choice == '4':
            return
        else:
            print("Invalid choice! Please enter a valid option.")

if __name__ == "__main__":
    user_tool()
