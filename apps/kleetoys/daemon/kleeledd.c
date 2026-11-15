// kleeledd: KleeToys icin kamera halkasi LED servisi (POCO X8 Pro "klee", Awinic AW21024).
// init soketi: /dev/socket/kleeledd (ANDROID_SOCKET_kleeledd). Satir protokolu:
//   q RRGGBB RRGGBB RRGGBB RRGGBB   ust sol, ust sag, alt sag, alt sol
//   off                             hepsini kapat
// Fiziksel eslesme (2026-11-15 dogrulandi): grup 3=ust sol, 5=ust sag, 4=alt sag, 6=alt sol; 0,1,2,7 bos.
// Son istemci baglantiyi kapatinca isiklar sondurulur.
#include <errno.h>
#include <fcntl.h>
#include <poll.h>
#include <stddef.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <unistd.h>

#define LED "/sys/class/leds/aw21024_led/"
#define MAXC 8
static const int GROUP[4] = {3, 5, 4, 6};
static int on;

static void wr(const char *f, const char *s) {
    int fd = open(f, O_WRONLY | O_CLOEXEC);
    if (fd < 0) return;
    (void)write(fd, s, strlen(s));
    close(fd);
}

static void led_on(void) {
    wr(LED "effect", "1");
    const int unused[4] = {0, 1, 2, 7};
    char b[16];
    for (int i = 0; i < 4; i++) { snprintf(b, sizeof b, "%d 000000", unused[i]); wr(LED "rgbcolor", b); }
    on = 1;
}

static void led_off(void) {
    char b[16];
    for (int i = 0; i < 4; i++) { snprintf(b, sizeof b, "%d 000000", GROUP[i]); wr(LED "rgbcolor", b); }
    wr(LED "effect", "0");
    on = 0;
}

static int hex6(const char *s) {
    if (strlen(s) != 6) return 0;
    for (int i = 0; i < 6; i++) {
        char c = s[i];
        if (!((c >= '0' && c <= '9') || (c >= 'a' && c <= 'f') || (c >= 'A' && c <= 'F'))) return 0;
    }
    return 1;
}

static void handle(char *line) {
    char *tok[6]; int n = 0;
    for (char *p = strtok(line, " \t\r"); p && n < 6; p = strtok(NULL, " \t\r")) tok[n++] = p;
    if (n == 0) return;
    if (!strcmp(tok[0], "off")) { if (on) led_off(); return; }
    if (!strcmp(tok[0], "q") && n == 5) {
        for (int i = 1; i < 5; i++) if (!hex6(tok[i])) return;
        if (!on) led_on();
        char b[16];
        for (int i = 0; i < 4; i++) { snprintf(b, sizeof b, "%d %s", GROUP[i], tok[i + 1]); wr(LED "rgbcolor", b); }
    }
}

static int get_socket(int argc, char **argv) {
    const char *e = getenv("ANDROID_SOCKET_kleeledd");
    if (e) return atoi(e);
    // Gelistirme: init disinda calistirilirsa soyut ad alaninda dinle (@kleeledd veya argv[1]).
    int s = socket(AF_UNIX, SOCK_STREAM | SOCK_CLOEXEC, 0);
    struct sockaddr_un a = {.sun_family = AF_UNIX};
    const char *name = argc > 1 ? argv[1] : "kleeledd";
    a.sun_path[0] = 0; strncpy(a.sun_path + 1, name, sizeof a.sun_path - 2);
    socklen_t len = offsetof(struct sockaddr_un, sun_path) + 1 + strlen(name);
    if (bind(s, (struct sockaddr *)&a, len) < 0) { perror("bind"); exit(1); }
    return s;
}

int main(int argc, char **argv) {
    int ls = get_socket(argc, argv);
    if (listen(ls, 4) < 0) { perror("listen"); return 1; }
    struct pollfd pf[MAXC + 1];
    char buf[MAXC][256]; int blen[MAXC];
    int nc = 0;
    pf[0].fd = ls; pf[0].events = POLLIN;
    for (;;) {
        if (poll(pf, nc + 1, -1) < 0) { if (errno == EINTR) continue; return 1; }
        if (pf[0].revents & POLLIN) {
            int c = accept4(ls, NULL, NULL, SOCK_CLOEXEC);
            if (c >= 0) {
                if (nc < MAXC) { pf[nc + 1].fd = c; pf[nc + 1].events = POLLIN; blen[nc] = 0; nc++; }
                else close(c);
            }
        }
        for (int i = 0; i < nc; i++) {
            if (!(pf[i + 1].revents & (POLLIN | POLLHUP | POLLERR))) continue;
            char tmp[512];
            ssize_t r = read(pf[i + 1].fd, tmp, sizeof tmp);
            if (r <= 0) {
                close(pf[i + 1].fd);
                pf[i + 1] = pf[nc]; memcpy(buf[i], buf[nc - 1], sizeof buf[i]); blen[i] = blen[nc - 1];
                nc--; i--;
                if (nc == 0 && on) led_off();
                continue;
            }
            for (ssize_t k = 0; k < r; k++) {
                if (tmp[k] == '\n') { buf[i][blen[i]] = 0; handle(buf[i]); blen[i] = 0; }
                else if (blen[i] < 255) buf[i][blen[i]++] = tmp[k];
                else blen[i] = 0; // asiri uzun satir: at
            }
        }
    }
}
