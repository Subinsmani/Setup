import os
import subprocess

def setup():
    print("Welcome to the setup script!")
    print("Please select your OS flavor:")
    print("1. Ubuntu")
    print("2. Windows")
    choice = input("Enter your choice (1/2): ")

    if choice == '1':
        os_flavor = 'Ubuntu'
    elif choice == '2':
        os_flavor = 'Windows'
    else:
        print("Invalid choice!")
        return

    print(f"Selected OS flavor: {os_flavor}")
    list_tools(os_flavor)

def list_tools(os_flavor):
    os_path = os.path.join(os.getcwd(), os_flavor)
    try:
        tool_scripts = [f[:-3] for f in os.listdir(os_path) if f.endswith('.py')]
        if not tool_scripts:
            print("No tools found for the selected OS.")
            return

        print("Available tools:")
        for idx, tool in enumerate(tool_scripts, start=1):
            print(f"{idx}. {tool}")

        tool_choice = int(input("Enter the number of the tool you want to run: ")) - 1
        if tool_choice < 0 or tool_choice >= len(tool_scripts):
            print("Invalid choice!")
            return

        selected_tool = tool_scripts[tool_choice] + '.py'
        run_tool_script(os_path, selected_tool)
    except FileNotFoundError:
        print("No tools directory found for the selected OS.")
    except ValueError:
        print("Invalid input. Please enter a number.")

def run_tool_script(os_path, tool_script):
    script_path = os.path.join(os_path, tool_script)
    try:
        subprocess.run(['python3', script_path], check=True)
    except FileNotFoundError:
        print(f"Tool script {tool_script} not found.")
    except subprocess.CalledProcessError as e:
        print(f"An error occurred while running the script: {e}")

if __name__ == "__main__":
    setup()
