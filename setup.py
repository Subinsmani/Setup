import os
import subprocess

def setup():
    while True:
        print("\nWelcome to the setup script!")
        print("Please select your OS flavor:")
        print("1. Ubuntu")
        print("2. Windows")
        print("3. Exit")
        choice = input("Enter your choice (1/2/3): ")

        if choice == '1':
            os_flavor = 'Ubuntu'
            list_tools(os_flavor)
        elif choice == '2':
            os_flavor = 'Windows'
            list_tools(os_flavor)
        elif choice == '3':
            print("Exiting...")
            break
        else:
            print("Invalid choice! Please enter a valid option.")

def list_tools(os_flavor):
    while True:
        os_path = os.path.join(os.getcwd(), os_flavor)
        try:
            tool_scripts = [f[:-3] for f in os.listdir(os_path) if f.endswith('.py')]
            if not tool_scripts:
                print("No tools found for the selected OS.")
                return

            print(f"\nAvailable tools for {os_flavor}:")
            for idx, tool in enumerate(tool_scripts, start=1):
                print(f"{idx}. {tool}")
            print(f"{len(tool_scripts) + 1}. Back")
            print(f"{len(tool_scripts) + 2}. Exit")

            tool_choice = input("Enter the number of the tool you want to run: ")
            
            if tool_choice.isdigit():
                tool_choice = int(tool_choice) - 1
                if 0 <= tool_choice < len(tool_scripts):
                    selected_tool = tool_scripts[tool_choice] + '.py'
                    run_tool_script(os_path, selected_tool)
                elif tool_choice == len(tool_scripts):
                    return  # Back to OS flavor selection
                elif tool_choice == len(tool_scripts) + 1:
                    print("Exiting...")
                    exit()
                else:
                    print("Invalid choice!")
            else:
                print("Invalid input. Please enter a number.")
        except FileNotFoundError:
            print("No tools directory found for the selected OS.")
            return

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
