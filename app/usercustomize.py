import os

try:
    import configgen.generators
    addons_dir = '/userdata/system/add-ons'
    if os.path.isdir(addons_dir):
        for addon in os.listdir(addons_dir):
            generator_path = os.path.join(addons_dir, addon, 'generator')
            if os.path.isdir(generator_path) and generator_path not in configgen.generators.__path__:
                configgen.generators.__path__ += [generator_path]
except Exception:
    pass
