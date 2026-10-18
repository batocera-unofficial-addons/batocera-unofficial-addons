#!/bin/bash
# Java Runtime uninstaller for Batocera. Removes the Java add-on, its desktop
# entry, the PATH/JAVA_HOME line in .profile and .bashrc and its custom.sh line.
#   curl -L https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/refs/heads/main/java/java_uninstall.sh | bash

# Same names and values as java.sh
APPNAME=java
CUSTOM_SH=/userdata/system/custom.sh

main() {
    echo "========================================="
    echo "Uninstalling: Java Runtime"
    echo "========================================="
    echo ""

    if [ -f "${CUSTOM_SH}" ]; then
        echo "Removing ${APPNAME} entry from custom.sh"
        # java.sh adds a blank line and then the entry; drop both
        awk -v entry="/userdata/system/add-ons/${APPNAME}/extra/startup" '
            $0 == entry { blank = 0; next }
            blank       { print ""; blank = 0 }
            $0 == ""    { blank = 1; next }
                        { print }
            END         { if (blank) print "" }
        ' "${CUSTOM_SH}" > "${CUSTOM_SH}.tmp"
        cat "${CUSTOM_SH}.tmp" > "${CUSTOM_SH}"
        rm -f "${CUSTOM_SH}.tmp"
    fi

    # Remove the line java.sh added; delete the file if that line was all it held
    for file in /userdata/system/.profile /userdata/system/.bashrc; do
        if [ -f "${file}" ]; then
            echo "Removing ${APPNAME} PATH and JAVA_HOME from ${file}"
            # shellcheck disable=SC2016  # literal $PATH: must match the line java.sh wrote
            grep -vxF 'export PATH=/userdata/system/add-ons/java/bin:$PATH && export JAVA_HOME=/userdata/system/add-ons/java' "${file}" > "${file}.tmp"
            cat "${file}.tmp" > "${file}"
            rm -f "${file}.tmp"
            [ -s "${file}" ] || rm -f "${file}"
        fi
    done

    echo "Removing desktop entry"
    rm -f "/usr/share/applications/${APPNAME}.desktop"

    echo "Removing /userdata/system/add-ons/${APPNAME}"
    rm -rf "/userdata/system/add-ons/${APPNAME}"

    echo ""
    echo "========================================="
    echo "Uninstallation complete: Java Runtime"
    echo "========================================="
}

main "$@"
