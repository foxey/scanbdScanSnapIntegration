# Scanbd ScanSnap Integration

Configuration and scan script to enable the scanner button on a Fujitsu
ScanSnap ix500 document scanner.

The script uses scanimage (from sane-utils) to scan the pages. After scanning
the images are analyzed with tesseract OCR and converted to single page PDF
files with the OCR results embedded to make the PDF searchable.
All single pages are concatenated with pdfunite (from poppler-utils).
The resulting PDF is sent by email using mime-construct.

I use it to send the files to a notebook in my Evernote account by appending the
notebook name to the subject line of the email.

The changes to the systemd configuration are necessary, because the default
timeouts cause systemd to kill the OCR process before it is finished.  I also
restart scanbd after each scan, as it crashes with a segfault while scanimage
is locking the usb connection during scanning. Anyone who has a more elegant
solution to handle this: please open an issue or make a pull request.

## Dependencies

* scanbd
* sane-utils (for scanimage)
* tesseract-ocr
* mime-construct

## Installation

### For Ubuntu

Install the dependencies

    sudo apt-get install scanbd sane-utils tesseract-ocr mime-construct

Get the configuration files and the scan script

    git clone https://github.com/foxey/scanbdScanSnapIntegration.git

Edit the script to fill-in your own email address

    cd scanbdScanSnapIntegration
    vi etc/scanbd/scripts/scan.sh

Copy the configuration and the script

    sudo cp -R etc /

Reload the systemd configuration

    sudo systemctl daemon-reload

Load a document in the scanner, push the button and check your mailbox!

# vim: set tw=79 ts=4 sw=4 expandtab si:
