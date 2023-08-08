import csv

# Load connections from CSV
connections = []
with open('connections.csv', 'r') as file:
    reader = csv.DictReader(file)
    for row in reader:
        connections.append(row)

# Function to display the tree in text format
def display_tree(node, indent=0, prefix=''):
    children = [conn for conn in connections if conn['Connection'] == node and conn['Type'] != 'Send']
    output = []
    for index, child in enumerate(children):
        is_last = index == len(children) - 1
        if is_last:
            current_prefix = prefix + '└── '
            child_prefix = prefix + '    '
        else:
            current_prefix = prefix + '├── '
            child_prefix = prefix + '│   '

        output.append(current_prefix + f"{child['Name']} ({child['SpeakerType']}) -> {child['Connection']} ({child['Type']})")
        
        # Adding FX as "children" for a given channel
        fx_sends = [conn for conn in connections if conn['Name'] == child['Name'] and conn['Type'] == 'Send']
        for fx in fx_sends:
            output.append(child_prefix + f"{fx['Connection']} (Send)")
        
        output.extend(display_tree(child['Name'], indent + 1, child_prefix))
    return output

# Invoke the function for the main node (Main)
tree_output = ["Main"]
tree_output.extend(display_tree("Main"))
tree_output_string = "\n".join(tree_output)

# Save the script results to output.txt
with open('output.txt', 'w', encoding='utf-8') as file:
    file.write(tree_output_string)

print("Results saved to output.txt")
