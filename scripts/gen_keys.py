'''

python3 gen_keys.py 100000 0.65 35000 1000 > init_keys.txt 2> actions.txt


'''


import sys
import random
import string
import itertools


def generate_unique_random_strings(count, length):
    unique_strings = set()
    characters = string.ascii_letters + string.digits
    
    while len(unique_strings) < count:
        # Generate a new random string
        random_string = ''.join(random.choices(characters, k=length))
        # Attempt to add the string to the set; the set handles uniqueness
        unique_strings.add(random_string)
    
    return unique_strings

# def generate_all_possible_strings(length=3):
#     chars = string.ascii_letters + string.digits  # "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
#     for item in itertools.product(chars, repeat=length):
#         print(f"{"".join(item)}")


# generate_all_possible_strings(4)




# -------------------------------------------------------------------------------------------------------------



def generate_actions(total_ops=1e6, total_keys=1e6, init_split=0.1, put_op_split=0.5, key_repetitions=True, separate_datasets=False):
    init_count = int(init_split * total_ops)
    rem_count = int(total_ops - init_count)

    assert not (total_ops > total_keys and not key_repetitions), f"Error: If Keys({total_keys}) are less than ops({total_ops}), key repetitions({key_repetitions}) must be true"

    ops = ["PUT", "GET"]
    probabilities = [put_op_split, 1 - put_op_split]

    unique_strings = generate_unique_random_strings(total_keys, 8)

    keys = list(unique_strings)

    if(separate_datasets):
        put_operations_count = int(total_ops * put_op_split)
        get_operations_count = int(total_ops * (1 - put_op_split))

        for i in range(put_operations_count):
            print(f'PUT: {random.choice(keys)} {random.randint(1, 100)}')

        for i in range(get_operations_count):
            print(f'GET: {random.choice(keys)}', file=sys.stderr)
        
        return

    for i in range(init_count):
        op = random.choices(ops, weights=probabilities, k=1)[0]
        if(op == "PUT"):
            print(f'PUT: {random.choice(keys)} {random.randint(1, 100)}')
        else:
            print(f'GET: {random.choice(keys)}')

    for i in range(rem_count):
        op = random.choices(ops, weights=probabilities, k=1)[0]
        if(op == "PUT"):
            print(f'PUT: {random.choice(keys)} {random.randint(1, 100)}', file=sys.stderr)
        else:
            print(f'GET: {random.choice(keys)}', file=sys.stderr)



'''
python3 ./gen_keys.py > ../samples/init_actions.txt 2> ../samples/actions.txt

# # Small Generic dataset
# generate_actions(total_ops=200, total_keys=75, init_split=0.2, put_op_split=0.5, key_repetitions=True)

# # Large Generic dataset
# generate_actions(total_ops=2e6, total_keys=1e6, init_split=0.2, put_op_split=0.5, key_repetitions=True)




python3 ./gen_keys.py > ../samples/put_ops.txt 2> ../samples/get_ops.txt

# # Generate Separate Put and Get datasets
# generate_actions(total_ops=2e6, total_keys=1e6, init_split=0.2, put_op_split=0.5, key_repetitions=True, separate_datasets=True)

'''
generate_actions(total_ops=2e6, total_keys=1e6, init_split=0.2, put_op_split=0.5, key_repetitions=True)
# generate_actions(total_ops=200, total_keys=75, init_split=0.2, put_op_split=0.5, key_repetitions=True)
# generate_actions(total_ops=2e6, total_keys=1e6, init_split=0.2, put_op_split=0.5, key_repetitions=True, separate_datasets=True)
