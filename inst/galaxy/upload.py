"""Upload an explicitly exported result; retain the staged copy on failure."""
import sys
import os

from galaxy_ie_helpers import get_galaxy_connection


if __name__ == "__main__":
    connection = get_galaxy_connection(obj=False)
    connection.tools.upload_file(sys.argv[1], os.environ["HISTORY_ID"])
