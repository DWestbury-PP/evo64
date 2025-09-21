def bin_to_commodore_assembly(input_file, output_file):
    with open(input_file, 'rb') as file:
        data = file.read()

    with open(output_file, 'w') as file:
        for i, byte in enumerate(data):
            if i % 64 == 0 and i != 0:
                file.write('\n')  # New line for a new sprite
            file.write(f"{byte}, ")

bin_to_commodore_assembly("sprite_data.bin", "sprite_data.asm")
