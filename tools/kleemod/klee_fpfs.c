// klee_fpfs: Samsung AODService/SystemUI parmak izi konumunu /sys/class/fingerprint/fingerprint/position'dan okuyor;
// Xiaomi çekirdeğinde yok. /sys/class'ın tmpfs kopyasını kurar (her alt klasör gerçek sysfs'ten bind), fingerprint/ ekler.
//   klee_fpfs test  <position>  : YALNIZ yeni, özel (MS_PRIVATE) mount ad alanında kurar, denetim komutlarını çalıştırır, çıkar.
//   klee_fpfs apply <position>  : geçerli ad alanında kurar (post-fs-data, zygote'tan önce).
// GELİŞTİRME ARACI (DSU). Slot A öncesi kaldırılacak.
#define _GNU_SOURCE
#include <dirent.h>
#include <errno.h>
#include <fcntl.h>
#include <sched.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mount.h>
#include <sys/stat.h>
#include <sys/xattr.h>
#include <unistd.h>

#define SRC "/dev/klee_sysclass"

static int wr(const char *p, const char *s) {
    int fd = open(p, O_WRONLY | O_CREAT | O_TRUNC, 0444);
    if (fd < 0) return -1;
    write(fd, s, strlen(s)); write(fd, "\n", 1); close(fd); return 0;
}

static void lbl(const char *p, const char *c) { if (lsetxattr(p, "security.selinux", c, strlen(c) + 1, 0)) fprintf(stderr, "etiket %s: %s\n", p, strerror(errno)); }

static int sync_binds(void) {  // kopyada olmayan yeni sinif klasorlerini ekle
    DIR *d = opendir(SRC); if (!d) return -1; struct dirent *e; char a[512], b[512]; int n = 0;
    while ((e = readdir(d))) {
        if (e->d_name[0] == '.' || !strcmp(e->d_name, "fingerprint")) continue;
        snprintf(b, sizeof b, "/sys/class/%s", e->d_name); struct stat st;
        if (!stat(b, &st)) continue;
        snprintf(a, sizeof a, SRC "/%s", e->d_name); mkdir(b, 0755); chmod(b, 0755);
        if (!mount(a, b, NULL, MS_BIND, NULL)) { printf("yeni sinif: %s\n", e->d_name); n++; }
    }
    closedir(d); return n;
}

static int build(const char *pos) {
    mkdir(SRC, 0755);
    if (mount("/sys/class", SRC, NULL, MS_BIND, NULL)) { perror("bind src"); return 1; }
    if (mount(NULL, SRC, NULL, MS_PRIVATE, NULL)) { perror("private src"); umount2(SRC, MNT_DETACH); return 1; }
    if (mount("klee_sysclass", "/sys/class", "tmpfs", MS_NOSUID | MS_NODEV | MS_NOEXEC,
              "mode=0755")) { perror("tmpfs"); return 1; }
    lbl("/sys/class", "u:object_r:sysfs:s0");
    DIR *d = opendir(SRC); if (!d) { perror("opendir"); umount2("/sys/class", MNT_DETACH); return 1; }
    struct dirent *e; int n = 0, fail = 0; char a[512], b[512];
    while ((e = readdir(d))) {
        if (e->d_name[0] == '.') continue;
        snprintf(a, sizeof a, SRC "/%s", e->d_name); snprintf(b, sizeof b, "/sys/class/%s", e->d_name);
        mkdir(b, 0755); chmod(b, 0755);
        if (mount(a, b, NULL, MS_BIND, NULL)) { fprintf(stderr, "BIND_FAIL %s: %s\n", e->d_name, strerror(errno)); fail++; } else n++;
    }
    closedir(d);
    if (fail) { fprintf(stderr, "bind hatasi %d -> geri aliniyor\n", fail); umount2("/sys/class", MNT_DETACH); return 1; }
    mkdir("/sys/class/fingerprint", 0755); chmod("/sys/class/fingerprint", 0755);
    mkdir("/sys/class/fingerprint/fingerprint", 0755); chmod("/sys/class/fingerprint/fingerprint", 0755);
    wr("/sys/class/fingerprint/fingerprint/position", pos); chmod("/sys/class/fingerprint/fingerprint/position", 0444);
    wr("/sys/class/fingerprint/fingerprint/adm", "1"); chmod("/sys/class/fingerprint/fingerprint/adm", 0444);
    const char *fc = "u:object_r:system_file:s0";  // tum uygulamalar okuyabilir
    lbl("/sys/class/fingerprint", fc); lbl("/sys/class/fingerprint/fingerprint", fc);
    lbl("/sys/class/fingerprint/fingerprint/position", fc); lbl("/sys/class/fingerprint/fingerprint/adm", fc);
    printf("kopya kuruldu: %d klasor\n", n);
    return 0;
}

int main(int argc, char **argv) {
    if (argc < 3) { fprintf(stderr, "kullanim: klee_fpfs test|apply <position>\n"); return 2; }
    if (!strcmp(argv[1], "test")) {
        if (unshare(CLONE_NEWNS)) { perror("unshare"); return 1; }
        if (mount(NULL, "/", NULL, MS_REC | MS_PRIVATE, NULL)) { perror("rprivate"); return 1; }
        printf("ozel ad alani OK\n"); fflush(stdout);
        if (build(argv[2])) return 1;
        printf("sync: %d\n", sync_binds());
        fflush(stdout);
        for (int i = 3; i < argc; i++) { printf("$ %s\n", argv[i]); fflush(stdout); system(argv[i]); fflush(stdout); }
        return 0;  // ad alanı süreçle birlikte yok olur
    }
    if (!strcmp(argv[1], "apply")) return build(argv[2]);
    if (!strcmp(argv[1], "sync")) return sync_binds() < 0;
    return 2;
}
