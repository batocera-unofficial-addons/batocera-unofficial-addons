#!/bin/bash
#!/bin/bash

# Get Batocera version
version=$(batocera-es-swissknife --version | awk '{print $1}' | sed 's/[^0-9]*//g')

# Check if version is one of the supported ones
case "$version" in
    38|39|40|41)
        echo "Detected Batocera version: $version"
        mkdir -p /userdata/extra && \
        wget -O - "https://github.com/git-developer/batocera-extra/tarball/batocera-$version" | \
        gunzip | tar x --strip-components 1 -C /userdata/extra
        ;;
    *)
        echo "Unsupported or unknown Batocera version: $version"
        exit 1
        ;;
esac

 mkdir -p /userdata/extra && wget -O - https://github.com/git-developer/batocera-extra/tarball/main | gunzip | tar x --strip-components 1 -C /userdata/extra
 /userdata/extra/bin/extra-services register
