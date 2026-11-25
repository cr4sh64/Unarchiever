# Unarchiever
A small 7-Zip-based tool for extracting archives

macOS 13+, Apple Silicon. Drop archives on the window: each one is extracted into a new folder next to it.

    ./build.sh   # build/Unarchiever.app
    ./test.sh    # self-check

## License

MIT, except `Vendor/7zz`: the unmodified [7-Zip](https://www.7-zip.org) 26.06 binary by Igor Pavlov ([source](https://github.com/ip7z/7zip/tree/26.06)), under the GNU LGPL with the unRAR restriction and BSD licenses, see [Vendor/7zz-License.txt](Vendor/7zz-License.txt).
