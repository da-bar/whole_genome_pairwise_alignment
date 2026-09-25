/*
 * Platform-dependent test references (tests/data/<dataset>/platform/<platform>/, see tests/data/README.md).
 *
 * axtChain, and the kent steps after it, give slightly different files on macOS and Linux (chains of equal score
 * come out in another order). The tests compare the chain, net, axt and liftOver files with references made by
 * tests/data/make_platform_fixtures.sh on the same platform, and keep them out of the nf-test snapshots.
 * nf-test puts this folder (tests/lib, its default libDir) on the class path of every test.
 */
class PlatformReferences {

    static final String SCRIPT = 'tests/data/make_platform_fixtures.sh'

    // Output files whose content depends on the platform: chains, nets, axt files and liftOver chains
    static final String PLATFORM_DEPENDENT = /.*\.(chain|net|axt)(\.gz)?$/

    /*
     * The platform key, `uname -s`-`uname -m` in lower case: darwin-arm64, linux-x86_64, linux-aarch64, ...
     * From the JVM's os.name and os.arch, or from the environment variable WGPA_TEST_PLATFORM, e.g. for
     * containers (-profile docker on macOS runs the linux-x86_64 tools).
     */
    static String platform() {
        def key = System.getenv('WGPA_TEST_PLATFORM')
        if (key) {
            return key
        }
        def os = System.getProperty('os.name').toLowerCase()
        os = os.startsWith('mac') || os.startsWith('darwin') ? 'darwin' : os.replaceAll(/\s+/, '')
        def arch = System.getProperty('os.arch').toLowerCase()
        if (arch in ['amd64', 'x86_64', 'x64']) {
            arch = 'x86_64'
        } else if (arch in ['aarch64', 'arm64']) {
            arch = os == 'darwin' ? 'arm64' : 'aarch64'
        }
        return "${os}-${arch}"
    }

    // tests/data/<dataset>/platform/<platform>. Fails if there are no references for this platform:
    // the tests never fall back to the references of another platform.
    static String dir(projectDir, String dataset) {
        def base = new File("${projectDir}/tests/data/${dataset}/platform")
        def dir = new File(base, platform())
        if (!dir.isDirectory()) {
            def known = (base.list() ?: new String[0]).findAll { name -> new File(base, name).isDirectory() }.sort().join(', ')
            throw new AssertionError(
                "No test references for platform '${platform()}' in tests/data/${dataset}/platform/ (there are: ${known}). " +
                "axtChain and the kent steps after it give slightly different chain, net and axt files on different " +
                "platforms, so the tests compare them with references made on the same platform. Make the references " +
                "for this platform with ${SCRIPT} (see tests/data/README.md), or, if the tools run in containers of " +
                "another platform, set WGPA_TEST_PLATFORM to that platform (e.g. linux-x86_64)."
            )
        }
        return dir.path
    }

    // A reference file of tests/data/<dataset>/platform/<platform>
    static String file(projectDir, String dataset, String name) {
        def f = new File(dir(projectDir, dataset), name)
        if (!f.isFile()) {
            throw new AssertionError("Test reference ${f} is missing: remake the references for platform '${platform()}' with ${SCRIPT}")
        }
        return f.path
    }

    // The "<md5>  <file name>" lines of one or more md5 files ('#' lines are comments). Looking up a name
    // that is not in the files fails, rather than giving null.
    static Md5List md5(String... paths) {
        def md5s = [:]
        paths.each { path ->
            def f = new File(path)
            if (!f.isFile()) {
                throw new AssertionError("Test reference ${f} is missing: remake the references for platform '${platform()}' with ${SCRIPT}")
            }
            f.eachLine { line ->
                if (line.trim() && !line.startsWith('#')) {
                    def fields = line.trim().split(/\s+/)
                    md5s[fields[1]] = fields[0]
                }
            }
        }
        return new Md5List(md5s, paths.join(', '))
    }

    // The [ meta, file ] tuples of a process output channel with file names instead of files, for the snapshot
    // of a platform-dependent output (the test checks its md5 against the platform references)
    static List fileNames(List channel) {
        return channel.collect { meta, f -> [ meta, new File(f.toString()).name ] }
    }

    // The files of a getAllFilesFromDir() list whose content does not depend on the platform (for snapshots) ...
    static List platformIndependent(List files) {
        return files.findAll { f -> !(new File(f.toString()).name ==~ PLATFORM_DEPENDENT) }
    }

    // ... and the names of those that do (each test checks them against its platform references)
    static List platformDependentNames(List files) {
        return files.collect { f -> new File(f.toString()).name }.findAll { name -> name ==~ PLATFORM_DEPENDENT }.sort()
    }

    // md5s by file name
    static class Md5List {

        private final Map<String, String> md5s
        private final String source

        Md5List(Map<String, String> md5s, String source) {
            this.md5s = md5s
            this.source = source
        }

        // refs['name'] and refs["${stem}.name"]
        String getAt(String name) {
            if (!md5s.containsKey(name)) {
                throw new AssertionError("No md5 for '${name}' in ${source}")
            }
            return md5s[name]
        }

        String getAt(GString name) {
            return getAt(name.toString())
        }

        int size() {
            return md5s.size()
        }

        String toString() {
            return "md5s of ${source}"
        }
    }
}
