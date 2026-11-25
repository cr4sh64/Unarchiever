import Foundation

let sevenZip = CommandLine.arguments[1]
let work = URL(fileURLWithPath: CommandLine.arguments[2]).resolvingSymlinksInPath()
let fm = FileManager.default
let extractor = Extractor(sevenZip: URL(fileURLWithPath: sevenZip))

func sh(_ command: String) {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: "/bin/sh")
    p.arguments = ["-ec", command]
    p.currentDirectoryURL = work
    p.environment = ["PATH": "/usr/bin:/bin", "Z": sevenZip]
    try! p.run()
    p.waitUntilExit()
    precondition(p.terminationStatus == 0, command)
}
func check(_ ok: Bool, _ label: String) {
    guard ok else { print("ÉCHEC : \(label)"); exit(1) }
    print("ok : \(label)")
}
func at(_ name: String) -> URL { work.appendingPathComponent(name) }
func content(_ folder: URL, _ file: String = "é a.txt") -> String? {
    try? String(contentsOf: folder.appendingPathComponent(file), encoding: .utf8)
}
func needsPassword(_ name: String, _ password: String?) -> Bool {
    do { _ = try extractor.extract(at(name), password: password); return false }
    catch ExtractError.passwordNeeded { return true }
    catch { return false }
}

sh("""
printf hi > 'é a.txt'
for e in 7z zip tar; do "$Z" a -bso0 -bsp0 plain-$e.$e 'é a.txt'; done
for c in z:gz j:bz2 J:xz; do tar c${c%%:*}f t-${c##*:}.tar.${c##*:} 'é a.txt'; done
tar czf short.tgz 'é a.txt'
cp plain-zip.zip 'joker[*]?.zip'
"$Z" a -bso0 -bsp0 -psecret enc.zip 'é a.txt'
"$Z" a -bso0 -bsp0 -psecret -mhe=on enc.7z 'é a.txt'
"$Z" a -bso0 -bsp0 -v100b multi.7z 'é a.txt'
printf nope > bad.zip
tar cf inner.tar 'é a.txt'; "$Z" a -bso0 -bsp0 holds.zip inner.tar
printf x > ro; chmod 555 ro; tar cf ro.tar ro; xattr -w com.apple.quarantine '0081;0;Test;' ro.tar
mkdir out esc; ln -s ../out esc/l; tar cf trav.tar esc/l; rm esc/l; mkdir esc/l; printf p > esc/l/pwn; tar rf trav.tar esc/l/pwn
cp plain-zip.zip q.zip; xattr -w com.apple.quarantine '0081;0;Test;' q.zip
mkdir evil; ln -s /private/tmp evil/lnk; tar cf evil.tar evil/lnk; rm -r evil
""")

for name in ["plain-7z.7z", "plain-zip.zip", "plain-tar.tar", "t-gz.tar.gz", "t-bz2.tar.bz2", "t-xz.tar.xz",
             "short.tgz", "joker[*]?.zip", "multi.7z.001"] {
    let folder = try extractor.extract(at(name))
    check(content(folder) == "hi" && folder.lastPathComponent == Extractor.baseName(of: at(name)), name)
    check((try fm.contentsOfDirectory(atPath: folder.path)).count == 1, "\(name) : rien d'autre dans le dossier")
}
check(try extractor.extract(at("plain-zip.zip")).lastPathComponent == "plain-zip 2", "n'écrase pas un dossier existant")
for name in ["enc.zip", "enc.7z"] {
    check(needsPassword(name, nil), "\(name) sans mot de passe")
    check(needsPassword(name, "faux"), "\(name) mauvais mot de passe")
    check(content(try extractor.extract(at(name), password: "secret")) == "hi", "\(name) bon mot de passe")
}
do { _ = try extractor.extract(at("bad.zip")); check(false, "archive invalide") }
catch ExtractError.failed(let message) { check(!message.isEmpty, "archive invalide : \(message)") }
check(fm.fileExists(atPath: try extractor.extract(at("holds.zip")).appendingPathComponent("inner.tar").path),
      "un .tar rangé dans un zip reste intact")
let q = try extractor.extract(at("q.zip"))
check(getxattr(q.appendingPathComponent("é a.txt").path, "com.apple.quarantine", nil, 0, 0, 0) > 0, "quarantaine propagée")
let ro = try extractor.extract(at("ro.tar")).appendingPathComponent("ro").path
check(getxattr(ro, "com.apple.quarantine", nil, 0, 0, 0) > 0, "quarantaine propagée en lecture seule")
check(access(ro, W_OK) != 0 && access(ro, X_OK) == 0, "droits d'origine conservés")
_ = try? extractor.extract(at("trav.tar"))
check(try fm.contentsOfDirectory(atPath: at("out").path).isEmpty, "pas d'écriture hors du dossier via un lien")
let link = try? fm.destinationOfSymbolicLink(atPath: try extractor.extract(at("evil.tar")).appendingPathComponent("evil/lnk").path)
check(link != "/private/tmp", "lien absolu non conservé")
check(try fm.contentsOfDirectory(atPath: work.path).allSatisfy { !$0.hasPrefix(".unarchiever") }, "aucun dossier temporaire restant")
