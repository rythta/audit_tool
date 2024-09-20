import subprocess
import random
import argparse
import sys
import logging

# Setup basic logging
logging.basicConfig(level=logging.INFO, format='%(levelname)s: %(message)s')

def generate_pseudorandom_locations(total_size, block_size, subsections=1000, samples_per_subsection=2):
    subsection_size = total_size // subsections
    remainder = total_size % subsections

    locations = []
    for i in range(subsections):
        start = i * subsection_size
        # Ensure that the end of the range accounts for the block size
        end = (start + subsection_size - block_size) if i < subsections - 1 else (total_size - block_size)

        for _ in range(samples_per_subsection):
            # Ensure the sample location allows for a full block read
            sample = random.randint(start, max(start, end))
            locations.append(sample)

    # Ensure the first location is included and adjust the last location to allow for a full block read
    locations.append(0)  # First addressable location
    if total_size - block_size > 0:
        locations.append(total_size - block_size)  # Adjusted to ensure the last block can be read

    return locations

def get_device_size(device):
    try:
        device_size = subprocess.check_output(['blockdev', '--getsize64', device]).strip().decode('utf-8')
        return int(device_size)
    except subprocess.CalledProcessError as e:
        print(f"Error retrieving device size: {e}")
        return None
    except ValueError:
        print("Received non-integer value for device size.")
        return None

def get_block_size(device):
    try:
        block_size = subprocess.check_output(['blockdev', '--getbsz', device]).strip().decode('utf-8')
        return int(block_size)
    except subprocess.CalledProcessError as e:
        print(f"Error retrieving block size: {e}")
        return None
    except ValueError:
        print("Received non-integer value for block size.")
        return None

def read_data(location, device, block_size):
    """
    Reads data from a given location on the device, aligning the read operation to block boundaries.

    Parameters:
    - location: The offset from where to start reading.
    - device: The device path.
    - block_size: The block size to use for reading.

    Returns:
    - The data read from the device, or None if an error occurred.
    """
    try:
        start_block = location // block_size
        offset_within_block = location % block_size
        actual_start_location = start_block * block_size

        # Determine the number of blocks to read to ensure the data includes the location offset
        count = 2 if offset_within_block else 1

        dd_command = ['dd', f'if={device}', f'bs={block_size}', f'skip={start_block}', f'count={count}']
        result = subprocess.run(dd_command, capture_output=True, check=True)

        data_start = offset_within_block
        data_end = offset_within_block + block_size if count == 2 else block_size
        data = result.stdout[data_start:data_end]

        if len(data) < block_size:
            logging.warning(f"Read data is shorter than expected at location {location}: expected {block_size} bytes, got {len(data)} bytes.")

        return data
    except Exception as e:
        logging.error(f"Error reading data from device: {e}")
        return None

def verify_locations(locations, block_size, expected_value, device):
    success_count = 0
    read_failure_count = 0

    for location in locations:
        data = read_data(location, device, block_size)
        if data is None:
            return False
            read_failure_count += 1
            continue

        data_len = len(data)
        expected_len = len(expected_value)

        if data_len < expected_len:
            logging.warning(f"Read data is shorter than expected at location {location}. Expected {expected_len} bytes, got {data_len} bytes.")
            return False  # Return failure on first occurrence of data being shorter than expected
        elif data != expected_value[:data_len]:
            logging.info(f"Data mismatch at location {location}.")
            return False  # Return failure on first data mismatch
        else:
            success_count += 1

    logging.info(f"Verification completed: {success_count} successes, {read_failure_count} read failures.")
    return True  # Return success if no mismatches or read failures occurred

def main():
    parser = argparse.ArgumentParser(description="Verify specific locations on a device.")
    parser.add_argument("--device", required=True, help="Device path (e.g., /dev/sdx)")
    parser.add_argument("--subsections", type=int, default=1000, help="Number of subsections to generate")
    parser.add_argument("--samples_per_subsection", type=int, default=2, help="Number of samples per subsection")
    args = parser.parse_args()

    device_size = get_device_size(args.device)
    if device_size is None:
        print("Failed to retrieve device size. Exiting.")
        sys.exit(1)

    block_size = get_block_size(args.device)
    if block_size is None:
        print("Could not determine block size, using default 512 bytes")
        block_size = 512

    # Set expected value to a sequence of zeros, with length equal to the block size.
    expected_value = bytes([0] * block_size)

    # Ensure the expected value is appropriately sized relative to block_size for comparison in verify_locations.
    if len(expected_value) != block_size:
        print(f"The length of the expected value ({len(expected_value)} bytes) does not match the block size ({block_size} bytes). Exiting.")
        sys.exit(1)

    locations = generate_pseudorandom_locations(device_size, block_size, args.subsections, args.samples_per_subsection)
    if verify_locations(locations, block_size, expected_value, args.device):
        print("Verification successful")
        sys.exit(0)
    else:
        print("Verification failed")
        sys.exit(1)

if __name__ == "__main__":
    main()
