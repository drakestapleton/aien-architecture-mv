/*
 * crumb: RFC-0001 Crumb Protocol (v1.0.0) + RFC-0002 common coordination plane (v1.1.0) tool. Single file, C11, no dependencies.
 * Spec: aien-spark/crumb-spec SPEC.md + ROLES.md (archived, pinned at 10b8251).
 *
 *   crumb seed <root> [-n] [-v]     write/refresh .crumb in every qualifying directory
 *   crumb create <dir> <name> <purpose> [layer]
 *   crumb claim <agent> <dir> <target> <intent> [ttl_seconds]   scent + advisory lock
 *   crumb update <agent> <dir> <focus> [ttl_seconds]            refresh scent
 *   crumb whisper <from> <dir> <to|-> <message> [priority] [target_file]
 *   crumb close <agent> <dir> <target> [action] [message]       release lock, history vector
 *   crumb sniff <agent> <dir>
 *   crumb list [path]
 *   crumb validate [path]
 *   crumb store-id [dir]            print the coordination store id (STORE_ID marker, shared with synapse-coord)
 *   crumb store-init [dir]          deliberately create a layout-2 (repository-namespaced) coordination root
 *   crumb check <agent> <dir> <target> [--generation N] [--key K]   read-only: is target covered by agent's valid lease?
 *   crumb --strict <command> ...    refuse an unregistered coordination store (also CRUMB_STRICT_STORE_ID=1)
 *   crumb --enforce <command> ...   fail-closed enforcement mode (also CRUMB_ENFORCE=1, git config crumb.enforce true)
 * Registered store identity: CRUMB_EXPECT_STORE_ID, else `git config crumb.storeId` (aien-architecture#234).
 * Repository identity (layout 2): CRUMB_REPO_ID, else `git config crumb.repoId`, else the origin URL as <owner>/<repo>.
 * Test-only clock: CRUMB_TEST_NOW=<epoch seconds> replaces the wall clock (tests of the expiry boundary; never set it
 * in production).
 */
#define _DEFAULT_SOURCE
#define _POSIX_C_SOURCE 200809L
#include <dirent.h>
#include <errno.h>
#include <stdint.h>
#include <fcntl.h>
#include <limits.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/wait.h>
#include <time.h>
#include <unistd.h>

#define SCHEMA "1.0.0"
#define HISTORY_CAP 20
#define SCENT_TTL 3600
#define LOCK_TTL 1800
#define MAX_TTL 315360000L   /* 3650 days: the largest ttl any command writes and the strict reader accepts (crumb924 B5) */
#define WHISPER_RETENTION (24 * 3600)

static void die(const char *fmt, ...) {
    va_list ap;
    va_start(ap, fmt);
    fprintf(stderr, "crumb: ");
    vfprintf(stderr, fmt, ap);
    fprintf(stderr, "\n");
    va_end(ap);
    exit(1);
}
static void *xmalloc(size_t n) { void *p = malloc(n ? n : 1); if (!p) die("out of memory"); return p; }
static void *xrealloc(void *q, size_t n) { void *p = realloc(q, n ? n : 1); if (!p) die("out of memory"); return p; }
static char *xstrdup(const char *s) { size_t n = strlen(s) + 1; char *p = xmalloc(n); memcpy(p, s, n); return p; }

/* ---------- growable buffer ---------- */
typedef struct { char *p; size_t n, cap; } Buf;
static void bput(Buf *b, const char *s, size_t n) {
    if (b->n + n + 1 > b->cap) { b->cap = (b->n + n + 1) * 2; b->p = xrealloc(b->p, b->cap); }
    memcpy(b->p + b->n, s, n); b->n += n; b->p[b->n] = 0;
}
static void bstr(Buf *b, const char *s) { bput(b, s, strlen(s)); }

/* ---------- minimal ordered JSON DOM (preserves unknown fields) ---------- */
enum { JNULL, JTRUE, JFALSE, JNUM, JSTR, JARR, JOBJ };
typedef struct J { int t; char *s; struct J **v; char **k; size_t n, cap; } J;

static J *jnew(int t) { J *j = xmalloc(sizeof *j); memset(j, 0, sizeof *j); j->t = t; return j; }
static J *jstr(const char *s) { J *j = jnew(JSTR); j->s = xstrdup(s); return j; }
static J *jnum(long x) { char t[32]; snprintf(t, sizeof t, "%ld", x); J *j = jnew(JNUM); j->s = xstrdup(t); return j; }
static void jgrow(J *a) { if (a->n == a->cap) { a->cap = a->cap ? a->cap * 2 : 4; a->v = xrealloc(a->v, a->cap * sizeof *a->v); if (a->t == JOBJ) a->k = xrealloc(a->k, a->cap * sizeof *a->k); } }
static void jpush(J *a, J *v) { jgrow(a); a->v[a->n++] = v; }
static J *jget(const J *o, const char *key) {
    if (!o || o->t != JOBJ) return NULL;
    for (size_t i = 0; i < o->n; i++) if (!strcmp(o->k[i], key)) return o->v[i];
    return NULL;
}
static void jset(J *o, const char *key, J *v) {
    for (size_t i = 0; i < o->n; i++) if (!strcmp(o->k[i], key)) { o->v[i] = v; return; }
    jgrow(o); o->k[o->n] = xstrdup(key); o->v[o->n++] = v;
}
static void jdel(J *o, const char *key) {
    for (size_t i = 0; i < o->n; i++) if (!strcmp(o->k[i], key)) {
        memmove(o->k + i, o->k + i + 1, (o->n - i - 1) * sizeof *o->k);
        memmove(o->v + i, o->v + i + 1, (o->n - i - 1) * sizeof *o->v);
        o->n--; return;
    }
}
static const char *jstrval(const J *o, const char *key) { J *v = jget(o, key); return v && v->t == JSTR ? v->s : NULL; }
static J *jobj_of(J *o, const char *key) {  /* get-or-create object member */
    J *v = jget(o, key);
    if (!v || v->t != JOBJ) { v = jnew(JOBJ); jset(o, key, v); }
    return v;
}
static J *jarr_of(J *o, const char *key) {
    J *v = jget(o, key);
    if (!v || v->t != JARR) { v = jnew(JARR); jset(o, key, v); }
    return v;
}

static void jescape(Buf *b, const char *s) {
    bput(b, "\"", 1);
    for (const unsigned char *p = (const unsigned char *)s; *p; p++) {
        char t[8];
        switch (*p) {
        case '"': bstr(b, "\\\""); break;
        case '\\': bstr(b, "\\\\"); break;
        case '\n': bstr(b, "\\n"); break;
        case '\r': bstr(b, "\\r"); break;
        case '\t': bstr(b, "\\t"); break;
        case '\b': bstr(b, "\\b"); break;
        case '\f': bstr(b, "\\f"); break;
        case 0x7f: bstr(b, "\\u007f"); break;
        default:
            if (*p < 0x20) { snprintf(t, sizeof t, "\\u%04x", *p); bstr(b, t); }
            else bput(b, (const char *)p, 1);
        }
    }
    bput(b, "\"", 1);
}
static void jprint(const J *j, Buf *b, int ind) {
    switch (j->t) {
    case JNULL: bstr(b, "null"); break;
    case JTRUE: bstr(b, "true"); break;
    case JFALSE: bstr(b, "false"); break;
    case JNUM: bstr(b, j->s); break;
    case JSTR: jescape(b, j->s); break;
    case JARR:
        if (!j->n) { bstr(b, "[]"); break; }
        bstr(b, "[\n");
        for (size_t i = 0; i < j->n; i++) {
            for (int s = 0; s < ind + 2; s++) bput(b, " ", 1);
            jprint(j->v[i], b, ind + 2);
            bstr(b, i + 1 < j->n ? ",\n" : "\n");
        }
        for (int s = 0; s < ind; s++) bput(b, " ", 1);
        bput(b, "]", 1); break;
    case JOBJ:
        if (!j->n) { bstr(b, "{}"); break; }
        bstr(b, "{\n");
        for (size_t i = 0; i < j->n; i++) {
            for (int s = 0; s < ind + 2; s++) bput(b, " ", 1);
            jescape(b, j->k[i]); bstr(b, ": ");
            jprint(j->v[i], b, ind + 2);
            bstr(b, i + 1 < j->n ? ",\n" : "\n");
        }
        for (int s = 0; s < ind; s++) bput(b, " ", 1);
        bput(b, "}", 1); break;
    }
}
static char *jdump(const J *j) { Buf b = {0}; jprint(j, &b, 0); bstr(&b, "\n"); return b.p; }

typedef struct { const char *p; int depth; int err; } P;
static void pws(P *p) { while (*p->p == ' ' || *p->p == '\t' || *p->p == '\n' || *p->p == '\r') p->p++; }
static void putf8(Buf *b, unsigned c) {
    if (c >= 0xD800 && c < 0xE000) c = 0xFFFD;
    char t[4]; int n;
    if (c < 0x80) { t[0] = (char)c; n = 1; }
    else if (c < 0x800) { t[0] = (char)(0xC0 | c >> 6); t[1] = (char)(0x80 | (c & 63)); n = 2; }
    else if (c < 0x10000) { t[0] = (char)(0xE0 | c >> 12); t[1] = (char)(0x80 | ((c >> 6) & 63)); t[2] = (char)(0x80 | (c & 63)); n = 3; }
    else { t[0] = (char)(0xF0 | c >> 18); t[1] = (char)(0x80 | ((c >> 12) & 63)); t[2] = (char)(0x80 | ((c >> 6) & 63)); t[3] = (char)(0x80 | (c & 63)); n = 4; }
    bput(b, t, (size_t)n);
}
static int hex4(const char *s, unsigned *out) {
    unsigned v = 0;
    for (int i = 0; i < 4; i++) {
        char c = s[i]; v <<= 4;
        if (c >= '0' && c <= '9') v |= (unsigned)(c - '0');
        else if (c >= 'a' && c <= 'f') v |= (unsigned)(c - 'a' + 10);
        else if (c >= 'A' && c <= 'F') v |= (unsigned)(c - 'A' + 10);
        else return 0;
    }
    *out = v; return 1;
}
static char *pstring(P *p) {
    Buf b = {0}; bstr(&b, "");
    p->p++;
    while (*p->p && *p->p != '"') {
        if (*p->p == '\\') {
            p->p++;
            switch (*p->p) {
            case 'n': bput(&b, "\n", 1); break;
            case 't': bput(&b, "\t", 1); break;
            case 'r': bput(&b, "\r", 1); break;
            case 'b': bput(&b, "\b", 1); break;
            case 'f': bput(&b, "\f", 1); break;
            case '/': case '\\': case '"': bput(&b, p->p, 1); break;
            case 'u': {
                unsigned c, d;
                if (!hex4(p->p + 1, &c)) { p->err = 1; return b.p; }
                p->p += 4;
                if (c >= 0xD800 && c < 0xDC00 && p->p[1] == '\\' && p->p[2] == 'u' && hex4(p->p + 3, &d) && d >= 0xDC00 && d < 0xE000) {
                    c = 0x10000 + ((c - 0xD800) << 10) + (d - 0xDC00); p->p += 6;
                }
                putf8(&b, c); break;
            }
            default: p->err = 1; return b.p;
            }
            p->p++;
        } else bput(&b, p->p++, 1);
    }
    if (*p->p != '"') p->err = 1; else p->p++;
    return b.p;
}
static J *pvalue(P *p) {
    pws(p);
    if (p->err || ++p->depth > 64) { p->err = 1; return NULL; }
    J *r = NULL;
    char c = *p->p;
    if (c == '{') {
        r = jnew(JOBJ); p->p++; pws(p);
        if (*p->p == '}') p->p++;
        else for (;;) {
            pws(p);
            if (*p->p != '"') { p->err = 1; break; }
            char *k = pstring(p); pws(p);
            if (*p->p != ':') { p->err = 1; break; }
            p->p++;
            J *v = pvalue(p); if (!v) break;
            jset(r, k, v); pws(p);
            if (*p->p == ',') { p->p++; continue; }
            if (*p->p == '}') { p->p++; break; }
            p->err = 1; break;
        }
    } else if (c == '[') {
        r = jnew(JARR); p->p++; pws(p);
        if (*p->p == ']') p->p++;
        else for (;;) {
            J *v = pvalue(p); if (!v) break;
            jpush(r, v); pws(p);
            if (*p->p == ',') { p->p++; continue; }
            if (*p->p == ']') { p->p++; break; }
            p->err = 1; break;
        }
    } else if (c == '"') { r = jnew(JSTR); r->s = pstring(p); }
    else if (!strncmp(p->p, "true", 4)) { r = jnew(JTRUE); p->p += 4; }
    else if (!strncmp(p->p, "false", 5)) { r = jnew(JFALSE); p->p += 5; }
    else if (!strncmp(p->p, "null", 4)) { r = jnew(JNULL); p->p += 4; }
    else if (c == '-' || (c >= '0' && c <= '9')) {
        const char *s = p->p;
        while (*p->p == '-' || *p->p == '+' || *p->p == '.' || *p->p == 'e' || *p->p == 'E' || (*p->p >= '0' && *p->p <= '9')) p->p++;
        r = jnew(JNUM); r->s = xmalloc((size_t)(p->p - s) + 1); memcpy(r->s, s, (size_t)(p->p - s)); r->s[p->p - s] = 0;
        { char *end; (void)strtod(r->s, &end); if (end == r->s || *end) p->err = 1; }
    } else p->err = 1;
    p->depth--;
    return p->err ? NULL : r;
}
static J *jparse(const char *s) {
    P p = { s, 0, 0 };
    J *j = pvalue(&p);
    if (!j) return NULL;
    pws(&p);
    return *p.p ? NULL : j;
}

/* ---------- files ---------- */
static char *slurp(const char *path) {
    FILE *f = fopen(path, "rb");
    if (!f) return NULL;
    Buf b = {0}; bstr(&b, "");
    char t[4096]; size_t n;
    while ((n = fread(t, 1, sizeof t, f)) > 0) bput(&b, t, n);
    fclose(f);
    return b.p;
}
/* Every file this tool creates is mode 0644 (minus umask), never 0666: fopen() would create it world-writable
 * under a permissive umask (CodeQL cpp/world-writable-file-creation). append=1 opens for appending. */
static FILE *fcreate(const char *path, int append) {
    int fd = open(path, O_WRONLY | O_CREAT | (append ? O_APPEND : O_TRUNC), 0644);
    if (fd < 0) return NULL;
    FILE *f = fdopen(fd, append ? "a" : "wb");
    if (!f) close(fd);
    return f;
}
static void spit(const char *path, const char *data) {
    size_t tn = strlen(path) + 32; char *tmp = xmalloc(tn);
    snprintf(tmp, tn, "%s.tmp%ld", path, (long)getpid());
    FILE *f = fcreate(tmp, 0);
    if (!f) die("cannot write %s: %s", tmp, strerror(errno));
    if (fputs(data, f) < 0 || fclose(f) != 0) die("write failed: %s", tmp);
    if (rename(tmp, path) != 0) die("rename failed: %s", path);
}
static char *pjoin(const char *a, const char *b) {
    size_t n = strlen(a) + strlen(b) + 2; char *p = xmalloc(n);
    snprintf(p, n, "%s/%s", a, b); return p;
}
static char *absdir(const char *d) {
    char r[PATH_MAX];
    if (!realpath(d, r)) die("no such directory: %s", d);
    struct stat st; if (stat(r, &st) || !S_ISDIR(st.st_mode)) die("not a directory: %s", d);
    return xstrdup(r);
}
static const char *base_of(const char *p) { const char *s = strrchr(p, '/'); return s && s[1] ? s + 1 : p; }

/* ---------- time ---------- */
/* CRUMB_TEST_NOW (test-only, documented in RFC-0002 section 2.8): a fixed epoch second instead of the wall clock, so
 * the lease expiry boundary can be tested exactly. Anything but decimal digits is refused. */
static long now_epoch(void) {
    const char *e = getenv("CRUMB_TEST_NOW");
    if (!e || !*e) return (long)time(NULL);
    for (const char *s = e; *s; s++) if (*s < '0' || *s > '9') die("CRUMB_TEST_NOW is \"%s\"; expected epoch seconds (test-only clock)", e);
    if (strlen(e) > 12) die("CRUMB_TEST_NOW is out of range: %s", e);
    return atol(e);
}
static void iso_of(long when, char *out) { time_t t = (time_t)when; struct tm tm; gmtime_r(&t, &tm); strftime(out, 21, "%Y-%m-%dT%H:%M:%SZ", &tm); }
static void now_iso(char *out) { iso_of(now_epoch(), out); }
static long parse_iso(const char *s) {  /* tolerant: first 19 chars, treated as UTC; -1 on failure */
    struct tm tm; memset(&tm, 0, sizeof tm);
    int y, mo, d, h, mi, se;
    if (!s || sscanf(s, "%d-%d-%dT%d:%d:%d", &y, &mo, &d, &h, &mi, &se) != 6) return -1;
    tm.tm_year = y - 1900; tm.tm_mon = mo - 1; tm.tm_mday = d; tm.tm_hour = h; tm.tm_min = mi; tm.tm_sec = se;
    return (long)timegm(&tm);
}
static long jlong(const J *o, const char *key, long dflt) { J *v = jget(o, key); return v && v->t == JNUM ? atol(v->s) : dflt; }
/* strict forms (enforcement mode, crumb check): exactly YYYY-MM-DDTHH:MM:SSZ with fields in range; a decimal u64 */
static int iso_strict(const char *s, long *out) {
    if (!s || strlen(s) != 20) return 0;
    for (int i = 0; i < 20; i++) {
        char c = s[i], want = i == 4 || i == 7 ? '-' : i == 10 ? 'T' : i == 13 || i == 16 ? ':' : i == 19 ? 'Z' : 0;
        if (want ? c != want : !(c >= '0' && c <= '9')) return 0;
    }
    int y, mo, d, h, mi, se;
    if (sscanf(s, "%4d-%2d-%2dT%2d:%2d:%2d", &y, &mo, &d, &h, &mi, &se) != 6) return 0;
    static const int mdays[] = { 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 };
    if (y < 1970 || mo < 1 || mo > 12 || h > 23 || mi > 59 || se > 59 || d < 1) return 0;
    int leap = (y % 4 == 0 && y % 100) || y % 400 == 0;
    if (d > mdays[mo - 1] + (mo == 2 && leap)) return 0;
    long v = parse_iso(s); if (v < 0) return 0;
    *out = v; return 1;
}
static int u64_str(const char *s, unsigned long long *out) {
    if (!s || !*s || strlen(s) > 20) return 0;
    for (const char *p = s; *p; p++) if (*p < '0' || *p > '9') return 0;
    if (s[0] == '0' && s[1]) return 0;   /* no leading zeros: one spelling per value */
    errno = 0; char *e; unsigned long long v = strtoull(s, &e, 10);
    if (errno || *e) return 0;
    *out = v; return 1;
}
static J *jnum_u64(unsigned long long x) { char t[32]; snprintf(t, sizeof t, "%llu", x); J *j = jnew(JNUM); j->s = xstrdup(t); return j; }

/* ---------- .crumb.local (ephemeral bus) ---------- */
typedef struct { char *path, *dir, *before; J *root; } Local;

static void sweep(J *root) {  /* SPEC 5.4 */
    long now = now_epoch();
    J *sc = jget(root, "active_scents");
    if (sc && sc->t == JOBJ) for (size_t i = sc->n; i-- > 0;) {
        long u = parse_iso(jstrval(sc->v[i], "updated_at"));
        if (u < 0 || now - u > jlong(sc->v[i], "ttl_seconds", SCENT_TTL)) jdel(sc, sc->k[i]);
    }
    J *lk = jget(root, "locks");
    if (lk && lk->t == JOBJ) for (size_t i = lk->n; i-- > 0;) {
        long u = parse_iso(jstrval(lk->v[i], "acquired_at"));
        if (u < 0 || now - u > jlong(lk->v[i], "ttl_seconds", LOCK_TTL)) jdel(lk, lk->k[i]);
    }
    J *wh = jget(root, "whispers");
    if (wh && wh->t == JARR) {
        size_t m = 0;
        for (size_t i = 0; i < wh->n; i++) {
            long u = parse_iso(jstrval(wh->v[i], "timestamp"));
            if (u >= 0 && now - u > WHISPER_RETENTION) continue;
            wh->v[m++] = wh->v[i];
        }
        wh->n = m;
    }
}
static Local local_open(const char *dir) {
    Local l; l.dir = absdir(dir); l.path = pjoin(l.dir, ".crumb.local");
    char *txt = slurp(l.path);
    l.root = txt ? jparse(txt) : NULL;
    if (txt && (!l.root || l.root->t != JOBJ)) die("%s is not valid JSON; fix or move it aside", l.path);
    if (!l.root) l.root = jnew(JOBJ);
    l.before = jdump(l.root);                 /* compare against the file as parsed, before any change */
    if (!jget(l.root, "schema_version")) {    /* adopt legacy/foreign file, keep every existing field */
        J *n = jnew(JOBJ); jset(n, "schema_version", jstr(SCHEMA)); jset(n, "directory", jstr(l.dir));
        for (size_t i = 0; i < l.root->n; i++) jset(n, l.root->k[i], l.root->v[i]);
        l.root = n;
    }
    if (!jget(l.root, "directory")) jset(l.root, "directory", jstr(l.dir));
    sweep(l.root);
    return l;
}
static char *run_git(const char *root, const char *args);
static void git_exclude_local(const char *dir) {   /* keep .crumb.local out of `git status` even before .gitignore lands */
    char *gp = run_git(dir, "rev-parse --git-path info/exclude");
    if (!*gp) return;
    char *full = gp[0] == '/' ? xstrdup(gp) : pjoin(dir, gp);
    char *txt = slurp(full);
    if (txt) { char *c = xstrdup(txt); for (char *l = strtok(c, "\n"); l; l = strtok(NULL, "\n")) if (!strcmp(l, ".crumb.local")) return; }
    FILE *f = fcreate(full, 1); if (!f) return;
    fputs(txt && *txt && txt[strlen(txt) - 1] != '\n' ? "\n.crumb.local\n" : ".crumb.local\n", f); fclose(f);
}
static void local_save(Local *l) {
    char *now = jdump(l->root);
    if (strcmp(now, l->before)) { spit(l->path, now); git_exclude_local(l->dir); }
}
static void history_add(J *root, const char *agent, const char *action, const char *target, const char *intent) {
    char ts[21]; now_iso(ts);
    J *h = jarr_of(root, "history"), *e = jnew(JOBJ);
    jset(e, "agent", jstr(agent)); jset(e, "action", jstr(action)); jset(e, "target", jstr(target));
    jset(e, "intent", jstr(intent)); jset(e, "vector", jstr("")); jset(e, "timestamp", jstr(ts));
    jpush(h, e);
    if (h->n > HISTORY_CAP) { size_t d = h->n - HISTORY_CAP; memmove(h->v, h->v + d, HISTORY_CAP * sizeof *h->v); h->n = HISTORY_CAP; }
}
static void whisper_add(J *root, const char *from, const char *to, const char *msg, const char *prio, const char *tf) {
    char ts[21]; now_iso(ts);
    J *w = jarr_of(root, "whispers"), *e = jnew(JOBJ);
    jset(e, "from", jstr(from));
    if (to && strcmp(to, "-")) jset(e, "to", jstr(to));
    jset(e, "message", jstr(msg));
    if (tf && *tf) jset(e, "target_file", jstr(tf));
    jset(e, "timestamp", jstr(ts));
    if (prio && *prio) jset(e, "priority", jstr(prio));
    jpush(w, e);
}
static void scent_set(J *root, const char *agent, const char *focus, long ttl) {
    char ts[21]; now_iso(ts);
    J *s = jobj_of(root, "active_scents"), *e = jget(s, agent);
    if (!e || e->t != JOBJ) { e = jnew(JOBJ); jset(s, agent, e); }
    jset(e, "focus", jstr(focus)); jset(e, "updated_at", jstr(ts)); jset(e, "ttl_seconds", jnum(ttl));
}
static int has_lock_by(J *root, const char *agent) {
    J *lk = jget(root, "locks");
    if (!lk || lk->t != JOBJ) return 0;
    for (size_t i = 0; i < lk->n; i++) { const char *h = jstrval(lk->v[i], "holder"); if (h && !strcmp(h, agent)) return 1; }
    return 0;
}
/* ---------- lease generation (fencing token) ----------
 * Per key, the generation strictly increases on every new acquisition (first claim, re-acquire after expiry, takeover
 * after release); a renewal by the current valid holder keeps it. The highest generation ever issued for a key is kept
 * in the record's "generations" map, which outlives the lease itself (close and expiry remove only the lease). */
static unsigned long long jgen(const J *o, const char *key) { J *v = jget(o, key); unsigned long long g; return v && v->t == JNUM && u64_str(v->s, &g) ? g : 0; }
static unsigned long long gen_next(J *rec, const char *path, const char *key, const J *cur, const char *agent) {
    J *gens = jget(rec, "generations");
    if (gens && gens->t != JOBJ) die("MALFORMED_RECORD: %s: \"generations\" is not an object; refusing (a reset counter would reuse fencing tokens)", path);
    gens = jobj_of(rec, "generations");
    unsigned long long last = jgen(gens, key), cg = cur ? jgen(cur, "generation") : 0;
    if (cg > last) last = cg;
    const char *h = cur ? jstrval(cur, "holder") : NULL;
    unsigned long long g = cur && cg && h && !strcmp(h, agent) ? cg : last + 1;
    if (!g) die("generation counter for %s is exhausted", key);
    /* the high-water mark never decreases: a renewal keeps the lease's generation but never lowers a larger
     * counter (crumb924 B6; enforcement mode refuses such a pair before this point, dir_record_strict) */
    jset(gens, key, jnum_u64(g > last ? g : last));
    return g;
}

/* ---------- operations ---------- */
static int legacy_claim(const char *agent, const char *dir, const char *target, const char *intent, long ttl) {
    Local l = local_open(dir);
    J *lk = jget(l.root, "locks");
    J *cur = lk ? jget(lk, target) : NULL;
    if (cur) {
        const char *h = jstrval(cur, "holder");
        if (h && strcmp(h, agent)) {   /* ROLES.md section 2: active lock on same target, must not proceed */
            printf("BLOCKED %s held by %s since %s (%s)\n", target, h, jstrval(cur, "acquired_at") ? jstrval(cur, "acquired_at") : "?", jstrval(cur, "intent") ? jstrval(cur, "intent") : "");
            return 2;
        }
    }
    char ts[21]; now_iso(ts);
    unsigned long long gen = gen_next(l.root, l.path, target, cur, agent);
    J *e = cur && cur->t == JOBJ ? cur : jnew(JOBJ);
    jset(e, "holder", jstr(agent)); jset(e, "intent", jstr(intent)); jset(e, "acquired_at", jstr(ts)); jset(e, "ttl_seconds", jnum(ttl));
    jset(e, "generation", jnum_u64(gen));
    jset(jobj_of(l.root, "locks"), target, e);
    scent_set(l.root, agent, intent, SCENT_TTL > ttl ? SCENT_TTL : ttl);
    local_save(&l);
    printf("CLAIMED %s in %s as %s (ttl %lds) generation %llu\n", target, l.dir, agent, ttl, gen);
    return 0;
}
static int legacy_update(const char *agent, const char *dir, const char *focus, long ttl) {
    Local l = local_open(dir);
    scent_set(l.root, agent, focus, ttl);
    local_save(&l);
    printf("SCENT %s in %s: %s (ttl %lds)\n", agent, l.dir, focus, ttl);
    return 0;
}
static int legacy_whisper(const char *from, const char *dir, const char *to, const char *msg, const char *prio, const char *tf) {
    if (prio && *prio && strcmp(prio, "low") && strcmp(prio, "normal") && strcmp(prio, "high") && strcmp(prio, "critical")) die("priority must be low|normal|high|critical");
    Local l = local_open(dir);
    whisper_add(l.root, from, to, msg, prio, tf);
    local_save(&l);
    printf("WHISPER %s -> %s in %s\n", from, to && strcmp(to, "-") ? to : "(broadcast)", l.dir);
    return 0;
}
static int legacy_close(const char *agent, const char *dir, const char *target, const char *action, const char *msg) {
    static const char *ok[] = { "create", "modify", "delete", "audit", "test", "build", NULL };
    int good = 0; for (int i = 0; ok[i]; i++) if (!strcmp(ok[i], action)) good = 1;
    if (!good) die("action must be create|modify|delete|audit|test|build");
    Local l = local_open(dir);
    J *lk = jget(l.root, "locks"), *cur = lk ? jget(lk, target) : NULL;
    const char *intent = "";
    if (cur) {
        const char *h = jstrval(cur, "holder");
        if (h && strcmp(h, agent)) { printf("REFUSED: %s is held by %s, not %s\n", target, h, agent); return 2; }
        if (jstrval(cur, "intent")) intent = jstrval(cur, "intent");
    }
    history_add(l.root, agent, action, target, intent);
    if (cur) jdel(lk, target);
    if (!has_lock_by(l.root, agent)) { J *sc = jget(l.root, "active_scents"); if (sc) jdel(sc, agent); }
    if (msg && *msg) whisper_add(l.root, agent, NULL, msg, "normal", target);
    local_save(&l);
    printf("CLOSED %s in %s by %s (%s)%s\n", target, l.dir, agent, action, cur ? "" : " [no lock was held]");
    return 0;
}
static void show_local(const char *dir, J *root, const char *agent) {
    J *sc = jget(root, "active_scents"), *lk = jget(root, "locks"), *wh = jget(root, "whispers");
    if (sc && sc->t == JOBJ) for (size_t i = 0; i < sc->n; i++)
        printf("  scent   %-16s %s  [%s, ttl %lds]\n", sc->k[i], jstrval(sc->v[i], "focus") ? jstrval(sc->v[i], "focus") : "", jstrval(sc->v[i], "updated_at") ? jstrval(sc->v[i], "updated_at") : "?", jlong(sc->v[i], "ttl_seconds", SCENT_TTL));
    if (lk && lk->t == JOBJ) for (size_t i = 0; i < lk->n; i++)
        printf("  lock    %-16s held by %s: %s  [%s]\n", lk->k[i], jstrval(lk->v[i], "holder") ? jstrval(lk->v[i], "holder") : "?", jstrval(lk->v[i], "intent") ? jstrval(lk->v[i], "intent") : "", jstrval(lk->v[i], "acquired_at") ? jstrval(lk->v[i], "acquired_at") : "?");
    if (wh && wh->t == JARR) for (size_t i = 0; i < wh->n; i++) {
        const char *to = jstrval(wh->v[i], "to"), *from = jstrval(wh->v[i], "from");
        if (agent && to && strcmp(to, agent)) continue;
        printf("  whisper %s -> %s: %s  [%s%s%s]\n", from ? from : "?", to ? to : "all", jstrval(wh->v[i], "message") ? jstrval(wh->v[i], "message") : "", jstrval(wh->v[i], "timestamp") ? jstrval(wh->v[i], "timestamp") : "?", jstrval(wh->v[i], "priority") ? " " : "", jstrval(wh->v[i], "priority") ? jstrval(wh->v[i], "priority") : "");
    }
    (void)dir;
}
static int legacy_sniff(const char *agent, const char *dir) {   /* SPEC 5.1 */
    char *d = absdir(dir), *cp = pjoin(d, ".crumb");
    char *txt = slurp(cp); J *c = txt ? jparse(txt) : NULL;
    printf("sniff %s as %s\n", d, agent);
    if (c) {
        J *inv = jget(c, "invariants");
        printf("  .crumb: %s | %s\n", jstrval(c, "name") ? jstrval(c, "name") : "?", jstrval(c, "purpose") ? jstrval(c, "purpose") : "(legacy format)");
        if (inv && inv->t == JARR) for (size_t i = 0; i < inv->n; i++) if (inv->v[i]->t == JSTR) printf("  invariant: %s\n", inv->v[i]->s);
    } else printf("  no .crumb here\n");
    Local l = local_open(d);
    show_local(d, l.root, agent);
    return 0;
}

/* ---------- RFC-0002 common coordination plane ----------
 * Inside a git repository all operational state lives in one store shared by every
 * worktree: <git-common-dir>/crumb/v1/{dirs,agents,continuations,ledger}. Outside git the
 * RFC-0001 .crumb.local behaviour above is used unchanged (legacy fallback). */
static void mkdir_p(const char *path);

typedef struct { char expect[33]; const char *source; int has_expect, warned; } Ident;   /* registered store identity, see below */
typedef struct { char *store, *top, *abs, *rel, *branch, *head, *base; Ident id; char *root, *repo_id; const char *repo_src; int layout; } Plane;
/* root: the coordination root (STORE_ID, LAYOUT, .lock). store: where records live, the root itself in layout 1,
 * <root>/repos/<repo-id> in layout 2 (NULL when layout 2 and no repository id resolved). */
typedef struct { char *path; J *root; char *before; int agent, dead, existed; } Rec;
typedef struct { Plane *p; Rec **r; size_t n, cap; int fd; } Txn;

static char *run_git_full(const char *root, const char *args) {
    Buf q = {0}; bstr(&q, "'");
    for (const char *p = root; *p; p++) { if (*p == '\'') bstr(&q, "'\\''"); else bput(&q, p, 1); }
    bstr(&q, "'");
    size_t cn = q.n + strlen(args) + 32; char *cmd = xmalloc(cn);
    snprintf(cmd, cn, "git -C %s %s 2>/dev/null", q.p, args);
    FILE *f = popen(cmd, "r"); Buf b = {0}; bstr(&b, "");
    if (!f) return b.p;
    char t[4096]; size_t n;
    while ((n = fread(t, 1, sizeof t, f)) > 0) bput(&b, t, n);
    pclose(f);
    return b.p;
}
static char *norm_path(const char *s) {   /* collapse . .. // ; NULL if it escapes the root */
    char *cp = xstrdup(s), **st = xmalloc((strlen(s) + 2) * sizeof *st); size_t n = 0;
    for (char *tok = strtok(cp, "/"); tok; tok = strtok(NULL, "/")) {
        if (!strcmp(tok, ".")) continue;
        if (!strcmp(tok, "..")) { if (!n) return NULL; n--; continue; }
        st[n++] = tok;
    }
    if (!n) return xstrdup(".");
    Buf b = {0}; bstr(&b, "");
    for (size_t i = 0; i < n; i++) { if (i) bstr(&b, "/"); bstr(&b, st[i]); }
    return b.p;
}
static char *dir_of(const char *p) { char *c = xstrdup(p), *s = strrchr(c, '/'); if (s) *s = 0; else strcpy(c, "."); return c; }
static char *key_dir(const char *key) { return strchr(key, '/') ? dir_of(key) : xstrdup("."); }
static int exists_at(const char *top, const char *rel) { char *f = pjoin(top, rel); struct stat st; int r = lstat(f, &st) == 0; free(f); return r; }
/* ---------- bounded store reads (aien-architecture#234; byte-compatible with synapse-coord record.rs, synapse#58) ----------
 * Anyone who can write into the shared coordination store can plant a FIFO, a device, a symlink to /dev/zero or a huge
 * file under a record name. Every read of a store file (dirs/ and agents/ records, continuations, STORE_ID, .lock) goes
 * through read_bounded: lstat first (a non-regular name is never opened), then open O_NOFOLLOW|O_NONBLOCK|O_CLOEXEC and
 * fstat the descriptor (catches a swap between the two), then read at most cap + 1 bytes. A refusal is fatal, named
 * REFUSED_RECORD, exit EXIT_REFUSED, and leaves the file as found. Caps match synapse-coord. */
#define MAX_RECORD_BYTES ((size_t)1 << 20)   /* records: dirs/ and agents/ JSON, continuations */
#define MAX_MARKER_BYTES ((size_t)4096)      /* STORE_ID */
#define EXIT_STORE_ID 3                      /* store identity refusal: STORE_ID_MISSING/MISMATCH/UNREADABLE/CONFIG_INVALID, STORE_UNREGISTERED */
#define EXIT_REFUSED 4                       /* hostile store file: REFUSED_RECORD */
static void die_x(int code, const char *fmt, ...) {
    va_list ap;
    va_start(ap, fmt);
    fprintf(stderr, "crumb: ");
    vfprintf(stderr, fmt, ap);
    fprintf(stderr, "\n");
    va_end(ap);
    exit(code);
}
static const char *kind_of(mode_t m) {
    if (S_ISLNK(m)) return "is a symbolic link";
    if (S_ISFIFO(m)) return "is a fifo, not a regular file";
    if (S_ISSOCK(m)) return "is a socket, not a regular file";
    if (S_ISCHR(m)) return "is a char device, not a regular file";
    if (S_ISBLK(m)) return "is a block device, not a regular file";
    if (S_ISDIR(m)) return "is a directory, not a regular file";
    return "is a special file, not a regular file";
}
static void refuse(const char *path, const char *why) {
    die_x(EXIT_REFUSED, "REFUSED_RECORD: %s %s; refusing to read it (fix or move it aside)", path, why);
}
static void refuse_big(const char *path, size_t cap) {
    char w[64]; snprintf(w, sizeof w, "is larger than %zu bytes", cap); refuse(path, w);
}
/* NULL when the name does not exist; *len gets the byte count (the buffer is also NUL-terminated). */
static char *read_bounded(const char *path, size_t cap, size_t *len) {
    struct stat st;
    if (lstat(path, &st) != 0) {
        if (errno == ENOENT) return NULL;
        if (errno == ENOTDIR) refuse(path, "has a parent that is not a directory");
        die("cannot stat %s: %s", path, strerror(errno));
    }
    if (!S_ISREG(st.st_mode)) refuse(path, kind_of(st.st_mode));
    int fd = open(path, O_RDONLY | O_NOFOLLOW | O_NONBLOCK | O_CLOEXEC);
    if (fd < 0) {
        if (errno == ENOENT) return NULL;
        if (errno == ELOOP) refuse(path, "is a symbolic link");
        die("cannot open %s: %s", path, strerror(errno));
    }
    if (fstat(fd, &st) != 0) die("cannot stat %s: %s", path, strerror(errno));
    if (!S_ISREG(st.st_mode)) refuse(path, kind_of(st.st_mode));
    if ((uintmax_t)st.st_size > (uintmax_t)cap) refuse_big(path, cap);
    Buf b = {0}; bstr(&b, "");
    char t[4096];
    while (b.n <= cap) {
        size_t want = cap + 1 - b.n; if (want > sizeof t) want = sizeof t;
        ssize_t r = read(fd, t, want);
        if (r < 0) { if (errno == EINTR) continue; die("read failed: %s: %s", path, strerror(errno)); }
        if (r == 0) break;
        bput(&b, t, (size_t)r);
    }
    close(fd);
    if (b.n > cap) refuse_big(path, cap);
    if (len) *len = b.n;
    return b.p;
}
/* Refuse a store path whose directory components below the store root are not all real directories: a write
 * through a symlinked directory would land outside the store, and a read would load a record the listing never
 * shows (collect_json does not follow symlinked directories). Missing components are fine (created later). */
static void check_real_parents(const char *store, const char *path) {
    size_t sl = strlen(store);
    if (strncmp(path, store, sl) || path[sl] != '/') refuse(path, "is outside the coordination store");
    char *c = dir_of(path);
    if (strlen(c) > sl) for (char *s = c + sl + 1;;) {
        char *slash = strchr(s, '/'); if (slash) *slash = 0;
        struct stat st;
        if (lstat(c, &st) != 0) { if (errno == ENOENT) break; die("cannot stat %s: %s", c, strerror(errno)); }
        if (S_ISLNK(st.st_mode)) refuse(c, "is a symbolic link");
        if (!S_ISDIR(st.st_mode)) refuse(c, "is not a directory");
        if (!slash) break;
        *slash = '/'; s = slash + 1;
    }
    free(c);
}
/* A fresh temp file: whatever has that name is unlinked first, never opened; O_EXCL|O_NOFOLLOW so the write can
 * neither block on a planted FIFO nor follow a planted link. */
static int create_temp(const char *tmp) {
    if (unlink(tmp) != 0 && errno != ENOENT) die("cannot remove stale %s: %s", tmp, strerror(errno));
    int fd = open(tmp, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC, 0644);
    if (fd < 0) die("cannot write %s: %s", tmp, strerror(errno));
    return fd;
}
static void write_all(int fd, const char *data, size_t len, const char *path) {
    size_t off = 0;
    while (off < len) { ssize_t w = write(fd, data + off, len - off); if (w < 0) { if (errno == EINTR) continue; die("write failed: %s", path); } off += (size_t)w; }
}
/* ---------- registered store identity (aien-architecture#234; byte-compatible with synapse-coord identity.rs, synapse#15) ----------
 * <store>/STORE_ID holds one line, "crumb-coord-store-id/1 <32 lowercase hex>\n" (128 bits from /dev/urandom).
 * Expected id: CRUMB_EXPECT_STORE_ID (non-empty) else `git config crumb.storeId`. Three modes:
 *   registered    an expected id is configured: before any operation, and again under the lock of a mutation, the
 *                 marker must exist and match (STORE_ID_MISSING / STORE_ID_MISMATCH, exit 3). Never creates a marker.
 *   compatibility nothing configured (default, dry run): works as before; the first mutation creates the marker
 *                 exactly as synapse-coord ensure_store_id does (under the lock, tmp + fsync + link(2), never
 *                 replacing one), and a one-line STORE_UNREGISTERED warning on stderr names the id to register.
 *   strict        --strict or CRUMB_STRICT_STORE_ID=1: an unregistered root is refused (STORE_UNREGISTERED, exit 3).
 * Outside a git repository (RFC-0001 .crumb.local fallback) there is no coordination store and nothing changes. */
#define STORE_ID_FILE "STORE_ID"
#define STORE_ID_FORMAT "crumb-coord-store-id/1"
static int g_strict;   /* --strict or CRUMB_STRICT_STORE_ID=1 */
static int g_enforce;  /* --enforce, CRUMB_ENFORCE=1 or git config crumb.enforce true: fail closed everywhere (implies strict) */
static int hex_id_ok(const char *s, size_t n) {
    if (n != 32) return 0;
    for (size_t i = 0; i < n; i++) if (!((s[i] >= '0' && s[i] <= '9') || (s[i] >= 'a' && s[i] <= 'f'))) return 0;
    return 1;
}
/* 1 and hex filled when <store>/STORE_ID is a valid v1 marker, 0 when absent; any other content is refused. */
static int read_marker(const char *store, char hex[33]) {
    char *mp = pjoin(store, STORE_ID_FILE); size_t n = 0;
    char *b = read_bounded(mp, MAX_MARKER_BYTES, &n);
    if (!b) { free(mp); return 0; }
    const char *why = NULL;
    const char *sp = n ? memchr(b, ' ', n - 1) : NULL;
    size_t fl = strlen(STORE_ID_FORMAT);
    if (!n || b[n - 1] != '\n') why = "no trailing newline (torn or foreign file)";
    else if (!sp) why = "expected `<format> <id>`";
    else if ((size_t)(sp - b) != fl || memcmp(b, STORE_ID_FORMAT, fl)) why = "unsupported format";
    else if (!hex_id_ok(sp + 1, n - 1 - fl - 1)) why = "bad id";
    if (why) die_x(EXIT_STORE_ID, "STORE_ID_UNREADABLE: %s is not a store identity marker: %s; refusing (never rewritten)", mp, why);
    memcpy(hex, sp + 1, 32); hex[32] = 0;
    free(b); free(mp);
    return 1;
}
static void fsync_dir(const char *dir);
/* Publish a new store marker file at path: tmp, fsync, link(2) (never replaces an existing file), dir fsync. */
static void publish_once(const char *dir, const char *path, const char *data, size_t len) {
    char *tmp = xmalloc(strlen(path) + 32);
    sprintf(tmp, "%s.tmp%ld", path, (long)getpid());
    int fd = create_temp(tmp);
    write_all(fd, data, len, tmp);
    if (fsync(fd) != 0) die("fsync failed: %s", tmp);
    if (close(fd) != 0) die("close failed: %s", tmp);
    int lr = link(tmp, path), le = errno;
    unlink(tmp);
    if (lr != 0 && le != EEXIST) die("cannot publish %s: %s", path, strerror(le));
    fsync_dir(dir);
    free(tmp);
}
/* Create the marker if absent; call only while holding the store's fcntl lock. link(2) never replaces an existing
 * file, so even a writer outside the lock cannot overwrite a marker. A crash before the link leaves only a tmp file. */
static void ensure_marker_locked(const char *store, char hex[33]) {
    if (read_marker(store, hex)) return;
    unsigned char rb[16]; size_t got = 0;
    int rf = open("/dev/urandom", O_RDONLY | O_CLOEXEC);
    if (rf < 0) die("cannot open /dev/urandom: %s", strerror(errno));
    while (got < sizeof rb) { ssize_t r = read(rf, rb + got, sizeof rb - got); if (r < 0 && errno == EINTR) continue; if (r <= 0) die("cannot read /dev/urandom"); got += (size_t)r; }
    close(rf);
    char line[64]; int ll = snprintf(line, sizeof line, "%s ", STORE_ID_FORMAT);
    for (size_t i = 0; i < sizeof rb; i++) ll += snprintf(line + ll, sizeof line - (size_t)ll, "%02x", rb[i]);
    line[ll++] = '\n'; line[ll] = 0;
    char *mp = pjoin(store, STORE_ID_FILE);
    publish_once(store, mp, line, (size_t)ll);
    if (!read_marker(store, hex)) die_x(EXIT_STORE_ID, "STORE_ID_MISSING: coordination store %s has no %s marker after creating it", store, STORE_ID_FILE);
    free(mp);
}
/* Ident (expected store id, its source, warned-once flag) is declared with Plane above. */
static Ident ident_resolve(const char *gitdir) {   /* gitdir NULL: no repository, environment only */
    Ident id; memset(&id, 0, sizeof id);
    const char *e = getenv("CRUMB_EXPECT_STORE_ID"); char *v = NULL;
    if (e && *e) { v = xstrdup(e); id.source = "CRUMB_EXPECT_STORE_ID"; }
    else if (gitdir) { char *c = run_git(gitdir, "config --get crumb.storeId"); if (*c) { v = c; id.source = "git config crumb.storeId"; } }
    if (!v) return id;
    if (!hex_id_ok(v, strlen(v))) die_x(EXIT_STORE_ID, "STORE_ID_CONFIG_INVALID: %s is \"%s\"; expected 32 lowercase hex characters (the id `crumb store-id` prints)", id.source, v);
    memcpy(id.expect, v, 33); id.has_expect = 1;
    return id;
}
static void ident_warn(Ident *id, const char *store, const char *hex) {
    if (id->warned) return;
    id->warned = 1;
    fprintf(stderr, "crumb: warning: STORE_UNREGISTERED (dry run): coordination store %s is store %s but no store id is registered; register it: git config crumb.storeId %s (strict mode, --strict or CRUMB_STRICT_STORE_ID=1, refuses unregistered stores)\n", store, hex, hex);
}
/* locked = 0: before any operation (read-only); locked = 1: inside a mutation, holding the store lock. */
static void ident_gate(Ident *id, const char *store, int locked) {
    char hex[33];
    if (id->has_expect) {
        if (!read_marker(store, hex))
            die_x(EXIT_STORE_ID, "STORE_ID_MISSING: coordination store %s has no %s marker; refusing (registered store %s via %s: check CRUMB_COORD_ROOT / crumb.coordinationRoot)", store, STORE_ID_FILE, id->expect, id->source);
        if (strcmp(hex, id->expect))
            die_x(EXIT_STORE_ID, "STORE_ID_MISMATCH: coordination store %s is store %s, expected %s (%s); refusing (split coordination roots)", store, hex, id->expect, id->source);
        return;
    }
    if (g_strict && !locked)
        die_x(EXIT_STORE_ID, "STORE_UNREGISTERED: coordination store %s has no registered store id (strict mode); register it: git config crumb.storeId <id> (from `crumb store-id`) or set CRUMB_EXPECT_STORE_ID", store);
    if (locked) { ensure_marker_locked(store, hex); ident_warn(id, store, hex); }
    else if (read_marker(store, hex)) ident_warn(id, store, hex);
}
/* stable session id, never a PID alone: CRUMB_SESSION if set, else agent@host */
static char *session_id(const char *agent) {
    const char *e = getenv("CRUMB_SESSION");
    if (e && *e) return xstrdup(e);
    char h[256]; if (gethostname(h, sizeof h) != 0) strcpy(h, "unknown-host");
    h[sizeof h - 1] = 0;
    size_t n = strlen(agent) + strlen(h) + 2; char *s = xmalloc(n); snprintf(s, n, "%s@%s", agent, h); return s;
}

/* ---------- repository namespaces (store layout 2) and enforcement mode (crumb924) ----------
 * Layout 1 (flat, the default and every store created before layout 2): records directly under the coordination root.
 * Layout 2: <root>/LAYOUT holds exactly "crumb-coord-layout/2\n"; records live under <root>/repos/<repo-id>/; STORE_ID
 * and .lock stay at the root. A root becomes layout 2 only through `crumb store-init` (refused while flat records
 * exist), so a flat store is never reinterpreted. Repository id: CRUMB_REPO_ID, else git config crumb.repoId, else the
 * origin remote URL normalised to <owner>/<repo> (lowercase); never the filesystem path. */
#define LAYOUT_FILE "LAYOUT"
#define LAYOUT_V2 "crumb-coord-layout/2\n"
static void collect_json(const char *dir, char ***out, size_t *n);
static int id_char(char c, int agent) {
    return (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9') || c == '.' || c == '_' || c == '-' || (agent && c == '@');
}
static int alnum_c(char c) { return (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9'); }
/* ^[A-Za-z0-9][A-Za-z0-9_.@-]{0,159}$ (layout 2 and enforcement mode: used verbatim as the record name, no aliases) */
static int agent_ok(const char *a) {
    size_t n = strlen(a);
    if (n < 1 || n > 160 || !alnum_c(a[0])) return 0;
    for (size_t i = 0; i < n; i++) if (!id_char(a[i], 1)) return 0;
    return 1;
}
static void agent_require(const Plane *p, const char *agent) {   /* p NULL: before resolution (enforcement only) */
    if (!(g_enforce || (p && p->layout == 2)) || agent_ok(agent)) return;
    die("AGENT_ID_INVALID: agent id \"%s\" must match ^[A-Za-z0-9][A-Za-z0-9_.@-]{0,159}$ (%s uses it verbatim; nothing is rewritten into an alias)", agent, g_enforce ? "enforcement mode" : "layout 2");
}
/* ^[A-Za-z0-9][A-Za-z0-9._-]*(/[A-Za-z0-9][A-Za-z0-9._-]*)?$; the second component may not be a record directory name
 * (dirs, agents, continuations, ledger), or namespace X/dirs would nest inside namespace X. */
static int repo_id_ok(const char *s) {
    size_t n = strlen(s);
    if (n < 1 || n > 200 || !alnum_c(s[0])) return 0;   /* a leading '/' (empty first component) would alias "x" (N2) */
    const char *sl = strchr(s, '/');
    if (sl && strchr(sl + 1, '/')) return 0;
    for (const char *c = s; *c; c++) {
        if (*c == '/') continue;
        if ((c == s || c[-1] == '/') && !alnum_c(*c)) return 0;
        if (!id_char(*c, 0)) return 0;
    }
    if (sl) {
        const char *b = sl + 1;
        if (!*b || !strcmp(b, "dirs") || !strcmp(b, "agents") || !strcmp(b, "continuations") || !strcmp(b, "ledger")) return 0;
    }
    return 1;
}
/* <owner>/<repo> from git@host:o/r(.git), ssh://[user@]host[:port]/o/r(.git), https://host/o/r(.git)(/); NULL for a
 * local path or file:// URL (a path is never an identity) or anything not exactly two path components. */
static char *repo_id_from_url(const char *url) {
    const char *path = NULL, *se = strstr(url, "://");
    if (se) {
        if (!strncmp(url, "file:", 5)) return NULL;
        const char *h = se + 3, *slash = strchr(h, '/');
        if (!slash || slash == h) return NULL;
        path = slash + 1;
    } else {
        const char *colon = strchr(url, ':'), *slash = strchr(url, '/');
        if (!colon || colon == url || (slash && slash < colon)) return NULL;   /* local path, not scp-like */
        path = colon + 1;
    }
    char *c = xstrdup(path); size_t n = strlen(c);
    while (n && c[n - 1] == '/') c[--n] = 0;
    if (n > 4 && !strcmp(c + n - 4, ".git")) c[n -= 4] = 0;
    while (n && c[n - 1] == '/') c[--n] = 0;
    char *s = c; while (*s == '/') s++;
    for (char *q = s; *q; q++) if (*q >= 'A' && *q <= 'Z') *q = (char)(*q - 'A' + 'a');
    if (!strchr(s, '/') || !repo_id_ok(s)) return NULL;
    return xstrdup(s);
}
static char *repo_id_resolve(const char *abs, const char **src) {
    const char *e = getenv("CRUMB_REPO_ID"); char *v = NULL;
    if (e && *e) { v = xstrdup(e); *src = "CRUMB_REPO_ID"; }
    else { char *c = run_git(abs, "config --get crumb.repoId"); if (*c) { v = c; *src = "git config crumb.repoId"; } }
    if (v) {
        if (!repo_id_ok(v)) die_x(EXIT_STORE_ID, "REPO_ID_INVALID: %s is \"%s\"; expected <owner>/<repo> matching ^[A-Za-z0-9][A-Za-z0-9._-]*(/[A-Za-z0-9][A-Za-z0-9._-]*)?$ (second component not dirs|agents|continuations|ledger)", *src, v);
        return v;
    }
    char *url = run_git(abs, "config --get remote.origin.url");
    *src = "origin remote URL";
    return *url ? repo_id_from_url(url) : NULL;
}
/* 1: no LAYOUT marker (flat); 2: exactly LAYOUT_V2; anything else is refused (exit 3; hostile file exit 4) */
static int read_layout(const char *root) {
    char *lp = pjoin(root, LAYOUT_FILE); size_t n = 0;
    char *b = read_bounded(lp, MAX_MARKER_BYTES, &n);
    if (!b) { free(lp); return 1; }
    if (n != strlen(LAYOUT_V2) || memcmp(b, LAYOUT_V2, n))
        die_x(EXIT_STORE_ID, "STORE_LAYOUT_UNSUPPORTED: %s is not \"crumb-coord-layout/2\"; refusing (never rewritten)", lp);
    free(b); free(lp);
    return 2;
}
/* A relative CRUMB_COORD_ROOT / crumb.coordinationRoot is anchored at the worktree top-level, not the process cwd,
 * and canonicalised (realpath when it exists, else lexically), so the cwd never changes the store. */
static char *root_canon(const char *v, const char *top) {
    if (v[0] == '/') return xstrdup(v);
    char *j = pjoin(top, v), r[PATH_MAX];
    if (realpath(j, r)) { free(j); return xstrdup(r); }
    char *n = norm_path(j + 1);
    if (!n) return j;
    char *a = xmalloc(strlen(n) + 2); sprintf(a, "/%s", n); free(j); free(n);
    return a;
}
static int bool_word(const char *v, const char *what) {   /* git-style boolean; anything else is refused */
    if (!strcmp(v, "1") || !strcmp(v, "true") || !strcmp(v, "yes") || !strcmp(v, "on")) return 1;
    if (!*v || !strcmp(v, "0") || !strcmp(v, "false") || !strcmp(v, "no") || !strcmp(v, "off")) return 0;
    die("%s is \"%s\"; expected true or false", what, v);
    return 0;
}
static void enforce_on(void) { g_enforce = 1; g_strict = 1; }
/* git config crumb.enforce, read with git's own boolean conversion (`git config --bool --get`: a valueless key, yes,
 * on, 1, any non-zero integer are true). 1 true, 0 false, -1 absent (git exit 1); any other outcome (a value git
 * refuses as a boolean, git failing to run) is an error, never "absent" (crumb924 N1). */
static int git_config_bool(const char *dir, const char *key) {
    Buf q = {0}; bstr(&q, "'");
    for (const char *p = dir; *p; p++) { if (*p == '\'') bstr(&q, "'\\''"); else bput(&q, p, 1); }
    bstr(&q, "'");
    size_t cn = q.n + strlen(key) + 64; char *cmd = xmalloc(cn);
    snprintf(cmd, cn, "git -C %s config --bool --get %s 2>/dev/null", q.p, key);
    FILE *f = popen(cmd, "r");
    if (!f) die("cannot run git to read git config %s: %s", key, strerror(errno));
    char t[64]; size_t n = fread(t, 1, sizeof t - 1, f); t[n] = 0;
    int st = pclose(f), rc = st != -1 && WIFEXITED(st) ? WEXITSTATUS(st) : -1;
    free(cmd); free(q.p);
    while (n && (t[n - 1] == '\n' || t[n - 1] == '\r')) t[--n] = 0;
    if (rc == 1 && !n) return -1;
    if (rc == 0 && !strcmp(t, "true")) return 1;
    if (rc == 0 && !strcmp(t, "false")) return 0;
    die("cannot read git config %s as a boolean (git exit %d%s%s); refusing to guess whether enforcement is on", key, rc, n ? ", output " : "", t);
    return 0;
}
static char *ns_path(const char *root, const char *repo_id) { char *r = pjoin(root, "repos"), *s = pjoin(r, repo_id); free(r); return s; }

static char *shq(const char *s);
/* run a git command in dir under the C locale: stdout (trailing newlines stripped) and the exit status (-1 when git
 * could not be run or did not exit); stderr is captured into *err when err is non-NULL, else discarded */
static char *git_rc(const char *dir, const char *args, int *rc, char **err) {
    char *q = shq(dir); size_t cn = strlen(q) + strlen(args) + 96; char *cmd = xmalloc(cn);
    if (err) snprintf(cmd, cn, "LC_ALL=C LANGUAGE=C git -C %s %s 2>&1 >/dev/null", q, args);
    else snprintf(cmd, cn, "LC_ALL=C LANGUAGE=C git -C %s %s 2>/dev/null", q, args);
    FILE *f = popen(cmd, "r"); Buf b = {0}; bstr(&b, "");
    *rc = -1;
    if (f) {
        char t[4096]; size_t n;
        while ((n = fread(t, 1, sizeof t, f)) > 0) bput(&b, t, n);
        int st = pclose(f); *rc = st != -1 && WIFEXITED(st) ? WEXITSTATUS(st) : -1;
    }
    free(cmd); free(q);
    while (b.n && (b.p[b.n - 1] == '\n' || b.p[b.n - 1] == '\r')) b.p[--b.n] = 0;
    if (err) { *err = b.p; return xstrdup(""); }
    return b.p;
}
static int has_git_ancestor(const char *abs) {   /* a .git entry (directory, gitdir file or link) in abs or above */
    char *d = xstrdup(abs);
    for (;;) {
        char *g = pjoin(*d ? d : "/", ".git"); struct stat st; int hit = lstat(g, &st) == 0; free(g);
        if (hit) { free(d); return 1; }
        char *s = strrchr(d, '/'); if (!s || !*d) break;
        *s = 0;
    }
    free(d); return 0;
}
/* Repository discovery (crumb924 B7). Returns the canonical work-tree top level, or NULL only when the directory is
 * positively established to be outside any repository: git's own discovery ran to its end ("not a git repository
 * (or any ...)", exit 128), or, with GIT_DIR unset, git did not succeed and no .git entry exists in the directory or
 * any ancestor. Every other failure (a malformed or unreadable .git/config, a .git file or GIT_DIR naming nothing,
 * dubious ownership, git not runnable inside a repository, a top level that does not contain the directory) is
 * GIT_DISCOVERY_FAILED (exit 1) in every mode, before anything is written: whether enforcement is configured cannot
 * be known, so the .crumb.local fallback is never taken on a discovery error. */
static char *git_discover(const char *abs) {
    int rc; char *top = git_rc(abs, "rev-parse --show-toplevel", &rc, NULL), r[PATH_MAX];
    if (rc == 0 && *top) {
        if (!realpath(top, r)) die("GIT_DISCOVERY_FAILED: git reports top level %s for %s but it cannot be resolved: %s; refusing (no .crumb.local fallback on a discovery error)", top, abs, strerror(errno));
        free(top); top = xstrdup(r);
        size_t tl = strlen(top);
        if (strncmp(abs, top, tl) || (abs[tl] && abs[tl] != '/'))
            die("GIT_DISCOVERY_FAILED: %s is not inside its git top level %s; refusing (no .crumb.local fallback on a discovery error)", abs, top);
        return top;
    }
    free(top);
    char *err = NULL; int rc2; git_rc(abs, "rev-parse --show-toplevel", &rc2, &err);
    const char *gd = getenv("GIT_DIR");
    int nonrepo = (rc == 128 && rc2 == 128 && strstr(err, "not a git repository (or any"))
               || (rc != 0 && !(gd && *gd) && !has_git_ancestor(abs));
    if (nonrepo) { free(err); return NULL; }
    char *nl = strchr(err, '\n'); if (nl && !strncmp(err, "warning:", 8) && nl[1]) memmove(err, nl + 1, strlen(nl + 1) + 1);
    if ((nl = strchr(err, '\n'))) *nl = 0;
    die("GIT_DISCOVERY_FAILED: git cannot establish whether %s is inside a repository (git rev-parse exit %d%s%s); refusing before any write (no .crumb.local fallback on a discovery error; fix the repository or its .git/config)", abs, rc, *err ? ": " : "", err);
    return NULL;
}
static Plane *plane_find(const char *dir) {   /* resolve the coordination root; no identity check yet */
    char *abs = absdir(dir), *top = git_discover(abs), r[PATH_MAX];
    if (!top) {
        if (g_enforce) die("ENFORCE_NO_REPOSITORY: %s is not inside a git repository; enforcement mode has no .crumb.local fallback", abs);
        return NULL;
    }
    size_t tl = strlen(top);
    if (!g_enforce && git_config_bool(abs, "crumb.enforce") == 1) enforce_on();
    Plane *p = xmalloc(sizeof *p); memset(p, 0, sizeof *p);
    p->abs = abs; p->top = top; p->rel = abs[tl] ? xstrdup(abs + tl + 1) : xstrdup(".");
    const char *env = getenv("CRUMB_COORD_ROOT");
    if (env && *env) p->root = root_canon(env, top);
    else { char *cfg = run_git(abs, "config --get crumb.coordinationRoot"); if (*cfg) p->root = root_canon(cfg, top); }
    if (!p->root) {
        char *cd = run_git(abs, "rev-parse --git-common-dir");
        if (!*cd) die("inside a git repository (%s) but cannot resolve its common directory; set CRUMB_COORD_ROOT", top);
        char *full = cd[0] == '/' ? cd : pjoin(abs, cd);
        if (!realpath(full, r)) die("cannot resolve git common directory %s; set CRUMB_COORD_ROOT", full);
        p->root = pjoin(r, "crumb/v1");
    }
    p->branch = run_git(abs, "symbolic-ref --short -q HEAD"); if (!*p->branch) p->branch = xstrdup("(detached)");
    p->head = run_git(abs, "rev-parse --short=12 HEAD");
    p->base = run_git(abs, "merge-base HEAD origin/main"); if (strlen(p->base) > 12) p->base[12] = 0;
    p->id = ident_resolve(abs);
    p->layout = read_layout(p->root);
    if (p->layout == 2 || g_enforce) p->repo_id = repo_id_resolve(abs, &p->repo_src);
    p->store = p->layout == 1 ? xstrdup(p->root) : p->repo_id ? ns_path(p->root, p->repo_id) : NULL;
    return p;
}
static size_t count_json(const char *dir) { char **f = NULL; size_t n = 0; collect_json(dir, &f, &n); for (size_t i = 0; i < n; i++) free(f[i]); free(f); return n; }
/* the conditions every coordination command needs on top of the store identity (enforcement mode fails closed) */
static void plane_require(Plane *p) {
    if (g_enforce && p->layout != 2)
        die_x(EXIT_STORE_ID, "STORE_LAYOUT_V1: coordination root %s has layout 1 (flat, no repository namespaces); enforcement mode needs layout 2: `crumb store-init` on a new or empty root (see RFC-0002 section 2.7)", p->root);
    if (p->layout != 2) return;
    if (!p->repo_id)
        die_x(EXIT_STORE_ID, "REPO_ID_MISSING: coordination root %s is namespaced (layout 2) but this repository has no id: set git config crumb.repoId <owner>/<repo> (or CRUMB_REPO_ID), or an origin remote URL host/<owner>/<repo>", p->root);
    char *fd = pjoin(p->root, "dirs"), *fa = pjoin(p->root, "agents");
    if (count_json(fd) + count_json(fa)) {
        if (g_enforce) die_x(EXIT_STORE_ID, "STORE_LAYOUT_MIXED: layout-2 root %s also holds flat (layout 1) records under dirs/ or agents/ (an older crumb wrote them); their locks are invisible here: refusing", p->root);
        fprintf(stderr, "crumb: warning: STORE_LAYOUT_MIXED: layout-2 root %s also holds flat records under dirs/ or agents/; they are ignored (enforcement mode refuses this)\n", p->root);
    }
    free(fd); free(fa);
    char *lp = pjoin(p->abs, ".crumb.local"); struct stat st;
    if (lstat(lp, &st) == 0) fprintf(stderr, "crumb: warning: %s is ignored: a layout-2 store never imports .crumb.local\n", lp);
    free(lp);
}
/* every coordination command: resolve the root, then check its identity before touching anything in it */
static Plane *plane_resolve(const char *dir) {
    Plane *p = plane_find(dir);
    if (p) { ident_gate(&p->id, p->root, 0); plane_require(p); }
    return p;
}
/* no repository (explain, checkpoint/resume with only CRUMB_COORD_ROOT): the records base of that root, after the
 * env-only identity check; a layout-2 root needs CRUMB_REPO_ID (there is no git config or origin to read) */
static char *env_store(const char *root) {
    Ident id = ident_resolve(NULL); ident_gate(&id, root, 0);
    if (read_layout(root) != 2) return xstrdup(root);
    const char *r = getenv("CRUMB_REPO_ID");
    if (!r || !*r) die_x(EXIT_STORE_ID, "REPO_ID_MISSING: coordination root %s is namespaced (layout 2); outside a repository set CRUMB_REPO_ID", root);
    if (!repo_id_ok(r)) die_x(EXIT_STORE_ID, "REPO_ID_INVALID: CRUMB_REPO_ID is \"%s\"", r);
    return ns_path(root, r);
}
/* repository-relative key for a target: <dir>/<target> if that exists, else <target> from the
 * repo root if that exists, else repo-relative as given when it contains '/', else <dir>/<target>.
 * An absolute path inside this worktree is made repo-relative, so two worktrees agree. */
static char *target_key(const Plane *p, const char *target, const char *rel) {
    if (target[0] == '/') {
        size_t tl = strlen(p->top);
        if (strncmp(target, p->top, tl) || target[tl] != '/') die("target %s is outside the repository %s", target, p->top);
        char *k = norm_path(target + tl + 1);
        if (!k) die("target %s escapes the repository", target);
        return k;
    }
    char *c1 = norm_path(strcmp(rel, ".") ? pjoin(rel, target) : target), *c2 = norm_path(target);
    if (c1 && strcmp(c1, ".") && exists_at(p->top, c1)) return c1;
    if (c2 && strcmp(c2, ".") && exists_at(p->top, c2)) return c2;
    if (strchr(target, '/') && c2) return c2;
    if (c1) return c1;
    if (c2) return c2;
    die("target %s escapes the repository", target);
    return NULL;
}
/* directory fsync after a rename or link; best effort normally, fatal in enforcement mode (EINVAL: the filesystem
 * cannot sync directories, which is not a failure to persist) */
static void fsync_dir(const char *dir) {
    int fd = open(dir, O_RDONLY);
    if (fd < 0) { if (g_enforce) die("cannot open directory %s to sync it: %s", dir, strerror(errno)); return; }
    if (fsync(fd) != 0 && g_enforce && errno != EINVAL) die("fsync of directory %s failed: %s", dir, strerror(errno));
    close(fd);
}
static void durable_write(const char *store, const char *path, const char *data) {   /* tmp, fsync, rename, fsync dir */
    size_t len = strlen(data);
    if (len > MAX_RECORD_BYTES) die_x(EXIT_REFUSED, "REFUSED_RECORD: %s would be larger than %zu bytes; refusing to write it", path, MAX_RECORD_BYTES);
    check_real_parents(store, path);
    struct stat st;   /* never rename over a planted FIFO, socket, device, symlink or directory */
    if (lstat(path, &st) == 0 && !S_ISREG(st.st_mode)) die_x(EXIT_REFUSED, "REFUSED_RECORD: %s %s; refusing to replace it (fix or move it aside)", path, kind_of(st.st_mode));
    char *dd = dir_of(path); mkdir_p(dd);
    size_t tn = strlen(path) + 32; char *tmp = xmalloc(tn);
    snprintf(tmp, tn, "%s.tmp%ld", path, (long)getpid());
    int fd = create_temp(tmp);
    write_all(fd, data, len, tmp);
    if (fsync(fd) != 0) die("fsync failed: %s", tmp);
    if (close(fd) != 0) die("close failed: %s", tmp);
    if (rename(tmp, path) != 0) die("rename failed: %s", path);
    fsync_dir(dd);
}
/* fcntl lock on <root>/.lock. create: open O_CREAT, exclusive lock (mutations); else shared lock on an existing lock
 * file and -1 when there is none (crumb check: creates nothing). A planted FIFO, device, symlink or directory is refused. */
static int root_lock(const char *root, int create) {
    char *lp = pjoin(root, ".lock");
    struct stat st;   /* the lock file is a store file too: a planted FIFO, device, symlink or directory is refused */
    if (lstat(lp, &st) == 0) { if (!S_ISREG(st.st_mode)) refuse(lp, kind_of(st.st_mode)); }
    else if (!create) { if (errno == ENOENT) { free(lp); return -1; } if (errno == ENOTDIR) refuse(lp, "has a parent that is not a directory"); die("cannot stat %s: %s", lp, strerror(errno)); }
    int fd = open(lp, (create ? O_RDWR | O_CREAT : O_RDONLY) | O_NOFOLLOW | O_NONBLOCK | O_CLOEXEC, 0644);
    if (fd < 0) {
        if (!create && errno == ENOENT) { free(lp); return -1; }
        if (errno == ELOOP) refuse(lp, "is a symbolic link");
        if (errno == EISDIR) refuse(lp, "is a directory, not a regular file");
        die("cannot open %s: %s", lp, strerror(errno));
    }
    if (fstat(fd, &st) != 0) die("cannot stat %s: %s", lp, strerror(errno));
    if (!S_ISREG(st.st_mode)) refuse(lp, kind_of(st.st_mode));
    struct flock fl; memset(&fl, 0, sizeof fl); fl.l_type = create ? F_WRLCK : F_RDLCK; fl.l_whence = SEEK_SET;
    while (fcntl(fd, F_SETLKW, &fl) != 0) if (errno != EINTR) die("cannot lock %s: %s", lp, strerror(errno));
    free(lp);
    return fd;
}
/* A root that any command has initialized or written: layout 2 (store-init creates .lock with LAYOUT), enforcement,
 * or a layout-1 root holding a marker or record directories (every first mutation creates .lock before them). Only a
 * never-used compatibility root may lack .lock; for crumb check that is plain absence (crumb924 B4). */
static int store_used(const Plane *p) {
    if (p->layout == 2 || g_enforce) return 1;
    static const char *names[] = { STORE_ID_FILE, LAYOUT_FILE, "dirs", "agents", NULL };
    for (int i = 0; names[i]; i++) { char *f = pjoin(p->root, names[i]); struct stat st; int e = lstat(f, &st) == 0; free(f); if (e) return 1; }
    return 0;
}
static Txn *txn_begin(Plane *p, int mutate) {
    Txn *t = xmalloc(sizeof *t); memset(t, 0, sizeof *t); t->p = p; t->fd = -1;
    if (!mutate) return t;
    mkdir_p(p->root);
    t->fd = root_lock(p->root, 1);   /* the lock exists before any record directory (crumb check relies on it, B4) */
    static const char *sub[] = { "dirs", "agents", "continuations", "ledger", NULL };
    for (int i = 0; sub[i]; i++) { char *d = pjoin(p->store, sub[i]); mkdir_p(d); free(d); }
    ident_gate(&p->id, p->root, 1);   /* under the lock: re-check the registered id, or create the marker once */
    if (read_layout(p->root) != p->layout) die("STORE_LAYOUT_CHANGED: coordination root %s changed layout while this command ran (store-init); retry", p->root);
    return t;
}
/* Strict lease schema (enforcement mode always; crumb check for the leases it judges): holder a non-empty string,
 * session a non-empty string, acquired_at YYYY-MM-DDTHH:MM:SSZ, ttl_seconds an integer in 1..MAX_TTL (what claim
 * accepts), generation an integer >= 1. Lenient (check
 * outside enforcement mode, layout-1 stores written by older tools): a parseable acquired_at, ttl_seconds >= 0 (default
 * LOCK_TTL when absent, as the sweep does), generation optional (0 when absent). Returns NULL or what is wrong. */
typedef struct { const char *holder, *session; long acq, ttl; unsigned long long gen; } Lease;
static const char *lease_parse(const J *e, int strict, Lease *l) {
    memset(l, 0, sizeof *l);
    if (!e || e->t != JOBJ) return "is not an object";
    J *h = jget(e, "holder"); if (!h || h->t != JSTR || !*h->s) return "holder is not a non-empty string";
    l->holder = h->s;
    J *a = jget(e, "acquired_at");
    if (!a || a->t != JSTR || !(strict ? iso_strict(a->s, &l->acq) : (l->acq = parse_iso(a->s)) >= 0)) return "acquired_at is not a YYYY-MM-DDTHH:MM:SSZ timestamp";
    J *t = jget(e, "ttl_seconds"); unsigned long long v = LOCK_TTL;
    if (t || strict) { if (!t || t->t != JNUM || !u64_str(t->s, &v) || v > (strict ? (unsigned long long)MAX_TTL : (unsigned long long)LONG_MAX / 4) || (strict && !v)) return strict ? "ttl_seconds is not an integer in 1..315360000" : "ttl_seconds is not a positive integer"; }
    l->ttl = (long)v;
    J *g = jget(e, "generation");
    if (g ? g->t != JNUM || !u64_str(g->s, &l->gen) || (strict && !l->gen) : strict) return "generation is not an integer >= 1";
    if (strict) { J *s = jget(e, "session"); if (!s || s->t != JSTR || !*s->s) return "session is not a non-empty string"; l->session = s->s; }
    return NULL;
}
static void malformed(const char *path, const char *key, const char *why) {
    die("MALFORMED_LEASE: %s: lease \"%s\" %s; refusing (enforcement mode never prunes or takes over a malformed lease: fix or move it aside)", path, key, why);
}
/* enforcement mode: a dir record must be exactly what this tool writes before anything is swept or decided */
static void dir_record_strict(const char *path, const J *j, const char *label) {
    J *lk = jget(j, "locks"), *gens = jget(j, "generations");
    if (lk && lk->t != JOBJ) die("MALFORMED_RECORD: %s: \"locks\" is not an object; refusing", path);
    if (gens && gens->t != JOBJ) die("MALFORMED_RECORD: %s: \"generations\" is not an object; refusing", path);
    if (gens) for (size_t i = 0; i < gens->n; i++) { unsigned long long g; if (gens->v[i]->t != JNUM || !u64_str(gens->v[i]->s, &g)) die("MALFORMED_RECORD: %s: generations[\"%s\"] is not an integer; refusing", path, gens->k[i]); }
    if (lk) for (size_t i = 0; i < lk->n; i++) {
        Lease l; const char *why = lease_parse(lk->v[i], 1, &l);
        if (why) malformed(path, lk->k[i], why);
        char *nk = norm_path(lk->k[i]), *kd = nk ? key_dir(nk) : NULL;
        if (!nk || strcmp(nk, lk->k[i]) || strcmp(kd, label)) malformed(path, lk->k[i], "is not a normalised key of this directory record");
        if (jgen(gens, lk->k[i]) != l.gen) malformed(path, lk->k[i], "has a generation that differs from the record's generations counter (the tool keeps them equal; a renewal would lower the high-water mark or reuse a token)");
        free(nk); free(kd);
    }
}
/* enforcement mode: an existing agent record must be what agent_set writes, or session ownership cannot be judged
 * (crumb924 B3: a malformed session is an error, never "no session") */
static void agent_record_strict(const char *path, const J *j) {
    const char *why = NULL; J *s = jget(j, "session"), *u = jget(j, "updated_at"), *t = jget(j, "ttl_seconds"), *a = jget(j, "agent");
    long acq; unsigned long long v;
    if (!a || a->t != JSTR || !*a->s) why = "agent is not a non-empty string";
    else if (!s || s->t != JSTR || !*s->s) why = "session is not a non-empty string";
    else if (!u || u->t != JSTR || !iso_strict(u->s, &acq)) why = "updated_at is not a YYYY-MM-DDTHH:MM:SSZ timestamp";
    else if (!t || t->t != JNUM || !u64_str(t->s, &v) || !v || v > (unsigned long long)MAX_TTL) why = "ttl_seconds is not an integer in 1..315360000";
    if (why) die("MALFORMED_RECORD: %s: agent record: %s; refusing (enforcement mode never treats malformed session metadata as absent: fix or move it aside)", path, why);
}
static Rec *rec_load(Txn *t, const char *path, int agent, const char *label) {
    for (size_t i = 0; i < t->n; i++) if (!strcmp(t->r[i]->path, path)) return t->r[i];
    Rec *r = xmalloc(sizeof *r); memset(r, 0, sizeof *r);
    if (t->n == t->cap) { t->cap = t->cap ? t->cap * 2 : 16; t->r = xrealloc(t->r, t->cap * sizeof *t->r); }
    t->r[t->n++] = r;
    r->path = xstrdup(path); r->agent = agent;
    check_real_parents(t->p->root, path);   /* never read through a symlinked directory (listing does not follow one) */
    size_t len = 0; char *txt = read_bounded(path, MAX_RECORD_BYTES, &len); J *j = txt && strlen(txt) == len ? jparse(txt) : NULL;
    if (txt && (!j || j->t != JOBJ)) die("%s is not valid JSON; fix or move it aside", path);
    r->existed = txt != NULL;
    if (!j) j = jnew(JOBJ);
    if (!agent && g_enforce) dir_record_strict(path, j, label);
    if (agent && g_enforce && r->existed) agent_record_strict(path, j);
    if (!agent) {
        if (!jget(j, "schema_version")) jset(j, "schema_version", jstr(SCHEMA));
        if (!jget(j, "directory")) jset(j, "directory", jstr(label));
    }
    r->root = j; r->before = jdump(j);
    if (agent) {
        long u = parse_iso(jstrval(j, "updated_at"));
        if (r->existed && (u < 0 || now_epoch() - u > jlong(j, "ttl_seconds", SCENT_TTL))) r->dead = 1;
    } else sweep(j);
    return r;
}
/* Directory record path. "." is dirs/_root.json in both layouts. Layout 2 (crumb924 B2): a first component that
 * starts with '_' gets one more '_' (`_root/x` -> dirs/__root/x.json, `_root` -> dirs/__root.json), so no repository
 * directory can map onto dirs/_root.json or dirs/_root/ and every record name maps back to exactly one key directory
 * (dir_label). Layout 1 keeps its historical mapping (where `_root` shares the root record) byte for byte. */
static char *dir_path(const Plane *p, const char *rel) {
    if (!strcmp(rel, ".")) return pjoin(p->store, "dirs/_root.json");
    char *a = pjoin(p->store, "dirs"), *b = p->layout == 2 && rel[0] == '_' ? xmalloc(strlen(a) + strlen(rel) + 3) : pjoin(a, rel), *c;
    if (p->layout == 2 && rel[0] == '_') sprintf(b, "%s/_%s", a, rel);
    c = xmalloc(strlen(b) + 6);
    sprintf(c, "%s.json", b); free(a); free(b); return c;
}
/* the key directory a record name under dirs/ (without .json) stands for; NULL when no key maps to that name */
static char *dir_label(const Plane *p, const char *name) {
    if (!strcmp(name, "_root")) return xstrdup(".");
    if (p->layout != 2 || name[0] != '_') return xstrdup(name);
    return name[1] == '_' ? xstrdup(name + 1) : NULL;
}
static Rec *dir_rec(Txn *t, const char *rel) { return rec_load(t, dir_path(t->p, rel), 0, rel); }
static char *agent_path(const Plane *p, const char *agent) {
    char *n = xstrdup(agent);   /* layout 1: legacy sanitising (aliases possible); layout 2: the validated id verbatim */
    if (p->layout != 2) for (char *s = n; *s; s++) if (!((*s >= 'a' && *s <= 'z') || (*s >= 'A' && *s <= 'Z') || (*s >= '0' && *s <= '9') || *s == '.' || *s == '-' || *s == '_')) *s = '_';
    char *a = pjoin(p->store, "agents"), *b = pjoin(a, n), *c = xmalloc(strlen(b) + 6);
    sprintf(c, "%s.json", b); return c;
}
static Rec *agent_rec(Txn *t, const char *agent) { return rec_load(t, agent_path(t->p, agent), 1, NULL); }
/* Record names under dir, recursively, without opening any entry: lstat, so real subdirectories are walked and
 * symlinked directories are not (no escape from the store, no symlink loop). Every other name ending in .json is
 * returned whatever its type; read_bounded then refuses a non-regular one without opening it. A missing top
 * directory is empty state. Any other failure to list (permissions, I/O, a vanished subdirectory) is fatal in
 * enforcement mode and a stderr warning otherwise: it is never silently treated as empty. */
static void walk_fail(const char *what, const char *path) {
    if (g_enforce) die("STORE_UNREADABLE: cannot %s %s: %s; refusing (enforcement mode never treats unreadable state as empty)", what, path, strerror(errno));
    fprintf(stderr, "crumb: warning: cannot %s %s: %s; records under it are ignored (enforcement mode refuses this)\n", what, path, strerror(errno));
}
static void collect_json_at(const char *dir, char ***out, size_t *n, int top) {
    DIR *d = opendir(dir);
    if (!d) { if (!(top && errno == ENOENT)) walk_fail("open directory", dir); return; }
    struct dirent *e;
    for (;;) {
        errno = 0;
        if (!(e = readdir(d))) { if (errno) walk_fail("read directory", dir); break; }
        if (!strcmp(e->d_name, ".") || !strcmp(e->d_name, "..")) continue;
        char *full = pjoin(dir, e->d_name); struct stat st;
        int ls = lstat(full, &st);
        if (ls != 0 && g_enforce) walk_fail("stat", full);
        if (ls == 0 && S_ISLNK(st.st_mode)) {   /* never followed; in enforcement mode never skipped either (crumb924 B1) */
            if (g_enforce) refuse(full, "is a symbolic link inside the coordination records (never followed; enforcement mode refuses to skip the records it may hide)");
            size_t l = strlen(e->d_name);
            if (!(l > 5 && !strcmp(e->d_name + l - 5, ".json"))) { fprintf(stderr, "crumb: warning: %s is a symbolic link; it is not walked and records under it are ignored (enforcement mode refuses this)\n", full); free(full); continue; }
        }
        if (ls == 0 && S_ISDIR(st.st_mode)) collect_json_at(full, out, n, 0);
        else { size_t l = strlen(e->d_name); if (l > 5 && !strcmp(e->d_name + l - 5, ".json")) { *out = xrealloc(*out, (*n + 1) * sizeof **out); (*out)[(*n)++] = full; continue; } }
        free(full);
    }
    closedir(d);
}
static void collect_json(const char *dir, char ***out, size_t *n) { collect_json_at(dir, out, n, 1); }
static void txn_prune(Txn *t) {   /* load every record: expired entries drop out (written back on commit) */
    char **f = NULL; size_t n = 0;
    char *dd = pjoin(t->p->store, "dirs"), *ad = pjoin(t->p->store, "agents");
    collect_json(dd, &f, &n);
    size_t pl = strlen(dd) + 1;
    for (size_t i = 0; i < n; i++) {
        char *rel = xstrdup(f[i] + pl); rel[strlen(rel) - 5] = 0;
        char *label = dir_label(t->p, rel);
        if (!label) {   /* layout 2: a '_' name no key maps to (an older layout-2 build wrote it, or it was planted) */
            if (g_enforce) die("MALFORMED_RECORD: %s is not a directory record name of layout 2 (a first component starting with '_' is stored as '__'; dirs/_root.json is only the repository root); refusing (fix or move it aside)", f[i]);
            fprintf(stderr, "crumb: warning: %s is not a directory record name of layout 2; it is ignored (enforcement mode refuses this)\n", f[i]);
            free(rel); continue;
        }
        rec_load(t, f[i], 0, label);
        free(rel);
    }
    char **g = NULL; size_t m = 0;
    collect_json(ad, &g, &m);
    for (size_t i = 0; i < m; i++) rec_load(t, g[i], 1, NULL);
}
static void txn_end(Txn *t, int commit) {
    if (commit) for (size_t i = 0; i < t->n; i++) {
        Rec *r = t->r[i];
        if (r->dead) { if (unlink(r->path) == 0) { char *d = dir_of(r->path); fsync_dir(d); free(d); } continue; }
        char *now = jdump(r->root);
        if (strcmp(now, r->before)) durable_write(t->p->root, r->path, now);
    }
    if (t->fd >= 0) close(t->fd);   /* releases the OS lock */
}
static J *jclone(const J *j) { char *s = jdump(j); J *c = jparse(s); free(s); return c ? c : jnew(JNULL); }
static void agent_set(Txn *t, const char *agent, const char *focus, long ttl) {
    Plane *p = t->p; char ts[21]; now_iso(ts);
    Rec *r = agent_rec(t, agent); r->dead = 0;
    J *e = jnew(JOBJ);
    jset(e, "agent", jstr(agent)); jset(e, "session", jstr(session_id(agent))); jset(e, "focus", jstr(focus)); jset(e, "dir", jstr(p->rel));
    jset(e, "worktree", jstr(p->top)); jset(e, "branch", jstr(p->branch)); jset(e, "head", jstr(p->head)); jset(e, "base", jstr(p->base));
    jset(e, "updated_at", jstr(ts)); jset(e, "ttl_seconds", jnum(ttl));
    r->root = e;
}
static int agent_has_lock(Txn *t, const char *agent) {
    for (size_t i = 0; i < t->n; i++) if (!t->r[i]->agent && has_lock_by(t->r[i]->root, agent)) return 1;
    return 0;
}
static void import_legacy(Txn *t) {   /* one-time merge of this worktree's .crumb.local into the shared store */
    Plane *p = t->p;
    if (p->layout == 2) return;   /* layout 2 never imports .crumb.local (plane_require warns when one is present) */
    char *lp = pjoin(p->abs, ".crumb.local"), *txt = slurp(lp);
    if (!txt) return;
    J *l = jparse(txt);
    if (!l || l->t != JOBJ) die("%s is not valid JSON; fix or move it aside", lp);
    Rec *dr = dir_rec(t, p->rel);
    J *mk = jarr_of(dr->root, "legacy_imported");
    for (size_t i = 0; i < mk->n; i++) if (mk->v[i]->t == JSTR && !strcmp(mk->v[i]->s, p->top)) return;
    sweep(l);
    J *lk = jget(l, "locks");
    if (lk && lk->t == JOBJ) for (size_t i = 0; i < lk->n; i++) {
        char *key = target_key(p, lk->k[i], p->rel), *td = key_dir(key);
        J *dst = jobj_of(dir_rec(t, td)->root, "locks");
        if (jget(dst, key)) continue;   /* never override newer shared state */
        J *e = jclone(lk->v[i]);
        jset(e, "target", jstr(key)); jset(e, "worktree", jstr(p->top)); jset(e, "imported_from", jstr(p->top));
        jset(dst, key, e);
    }
    J *sc = jget(l, "active_scents");
    if (sc && sc->t == JOBJ) for (size_t i = 0; i < sc->n; i++) {
        Rec *ar = agent_rec(t, sc->k[i]);
        if (jget(ar->root, "updated_at") && !ar->dead) continue;
        J *e = jnew(JOBJ);
        jset(e, "agent", jstr(sc->k[i])); jset(e, "focus", jstr(jstrval(sc->v[i], "focus") ? jstrval(sc->v[i], "focus") : ""));
        jset(e, "dir", jstr(p->rel)); jset(e, "worktree", jstr(p->top)); jset(e, "branch", jstr("")); jset(e, "head", jstr("")); jset(e, "base", jstr(""));
        jset(e, "updated_at", jstr(jstrval(sc->v[i], "updated_at") ? jstrval(sc->v[i], "updated_at") : ""));
        jset(e, "ttl_seconds", jnum(jlong(sc->v[i], "ttl_seconds", SCENT_TTL))); jset(e, "imported_from", jstr(p->top));
        ar->root = e; ar->dead = 0;
    }
    J *wh = jget(l, "whispers");
    if (wh && wh->t == JARR) for (size_t i = 0; i < wh->n; i++) {
        J *e = jclone(wh->v[i]); jset(e, "imported_from", jstr(p->top)); jpush(jarr_of(dr->root, "whispers"), e);
    }
    J *hi = jget(l, "history");
    if (hi && hi->t == JARR && hi->n) {
        J *h = jarr_of(dr->root, "history");
        for (size_t i = 0; i < hi->n; i++) { J *e = jclone(hi->v[i]); jset(e, "imported_from", jstr(p->top)); jpush(h, e); }
        if (h->n > HISTORY_CAP) { size_t d = h->n - HISTORY_CAP; memmove(h->v, h->v + d, HISTORY_CAP * sizeof *h->v); h->n = HISTORY_CAP; }
    }
    jpush(mk, jstr(p->top));
}
static const char *sv(const J *o, const char *k) { const char *s = jstrval(o, k); return s ? s : ""; }
static void print_lock(const char *key, const J *e) {
    printf("  lock    %-16s held by %s [%s]: %s  [%s]%s%s\n", key, sv(e, "holder"), sv(e, "branch"), sv(e, "intent"), sv(e, "acquired_at"),
           jstrval(e, "imported_from") ? " imported from " : "", jstrval(e, "imported_from") ? jstrval(e, "imported_from") : "");
}
/* anc is k itself or one of its ancestor keys ("." is the whole repository) */
static int key_covers(const char *anc, const char *k) {
    if (!strcmp(anc, ".") || !strcmp(anc, k)) return 1;
    size_t n = strlen(anc);
    return !strncmp(k, anc, n) && k[n] == '/';
}
/* enforcement mode: an agent id names exactly one live session; a second session presenting it is refused (exit 2).
 * Live means a live heartbeat from another session, or a live lease of this id recorded by another session: the
 * heartbeat can expire long before the lease, and the lease's session decides who may renew or close it (crumb924 B3).
 * Every dir record is loaded and swept (txn_prune) before this runs, so the leases left are the live ones. */
static int agent_in_use(Txn *t, const char *agent) {
    if (!g_enforce) return 0;
    Rec *r = agent_rec(t, agent);
    const char *s = jstrval(r->root, "session");
    char *me = session_id(agent);
    if (r->existed && !r->dead && s && strcmp(s, me)) {
        printf("BLOCKED agent %s is live in session %s, not this session %s (an agent id names one session: use <agent-name>.<session-id>)\n", agent, s, me);
        free(me); return 1;
    }
    for (size_t i = 0; i < t->n; i++) if (!t->r[i]->agent) {
        J *lk = jget(t->r[i]->root, "locks");
        if (lk && lk->t == JOBJ) for (size_t k = 0; k < lk->n; k++) {
            const char *h = jstrval(lk->v[k], "holder"), *ls = jstrval(lk->v[k], "session");
            if (!h || strcmp(h, agent)) continue;
            if (!ls) die("MALFORMED_LEASE: %s: lease \"%s\" has no session; refusing", t->r[i]->path, lk->k[k]);   /* dir_record_strict already refused it */
            if (strcmp(ls, me)) {
                printf("BLOCKED agent %s is live in session %s, not this session %s (live lease on %s generation %s; an agent id names one session: use <agent-name>.<session-id>)\n", agent, ls, me, lk->k[k], jget(lk->v[k], "generation") ? jget(lk->v[k], "generation")->s : "?");
                free(me); return 1;
            }
        }
    }
    free(me);
    return 0;
}
static int cmd_claim(const char *agent, const char *dir, const char *target, const char *intent, long ttl) {
    Plane *p = plane_resolve(dir);
    if (!p) return legacy_claim(agent, dir, target, intent, ttl);
    agent_require(p, agent);
    if (g_enforce && ttl <= 0) die("enforcement mode needs a positive ttl (got %ld)", ttl);
    char *key = target_key(p, target, p->rel), *td = key_dir(key);
    Txn *t = txn_begin(p, 1); txn_prune(t); import_legacy(t);
    if (agent_in_use(t, agent)) { txn_end(t, 0); return 2; }
    Rec *tr = dir_rec(t, td);
    J *cur = jget(jobj_of(tr->root, "locks"), key);
    if (cur) {
        const char *h = jstrval(cur, "holder");
        if (h && strcmp(h, agent)) {
            printf("BLOCKED %s held by %s on branch %s (worktree %s) since %s (%s)\n", key, h, sv(cur, "branch"), sv(cur, "worktree"), sv(cur, "acquired_at"), sv(cur, "intent"));
            txn_end(t, 1);
            return 2;
        }
    }
    /* no overlap: another agent's valid lease on an ancestor or a descendant of key blocks too (expired ones are pruned) */
    for (size_t i = 0; i < t->n; i++) if (!t->r[i]->agent) {
        J *lk = jget(t->r[i]->root, "locks");
        if (lk && lk->t == JOBJ) for (size_t k = 0; k < lk->n; k++) {
            const char *h = jstrval(lk->v[k], "holder");
            if (!h || !strcmp(h, agent) || !(key_covers(lk->k[k], key) || key_covers(key, lk->k[k]))) continue;
            J *o = lk->v[k];
            printf("BLOCKED %s held by %s on branch %s (worktree %s) since %s (%s) [overlapping lease on %s]\n", key, h, sv(o, "branch"), sv(o, "worktree"), sv(o, "acquired_at"), sv(o, "intent"), lk->k[k]);
            txn_end(t, 1);
            return 2;
        }
    }
    char ts[21]; now_iso(ts);
    unsigned long long gen = gen_next(tr->root, tr->path, key, cur, agent);
    J *e = jnew(JOBJ);
    jset(e, "holder", jstr(agent)); jset(e, "session", jstr(session_id(agent))); jset(e, "target", jstr(key)); jset(e, "intent", jstr(intent));
    jset(e, "worktree", jstr(p->top)); jset(e, "branch", jstr(p->branch)); jset(e, "head", jstr(p->head)); jset(e, "base", jstr(p->base));
    jset(e, "acquired_at", jstr(ts)); jset(e, "ttl_seconds", jnum(ttl)); jset(e, "generation", jnum_u64(gen));
    jset(jobj_of(tr->root, "locks"), key, e);
    agent_set(t, agent, intent, SCENT_TTL > ttl ? SCENT_TTL : ttl);
    txn_end(t, 1);
    printf("CLAIMED %s in %s as %s on %s (ttl %lds) generation %llu\n", key, p->top, agent, p->branch, ttl, gen);
    return 0;
}
static int cmd_update(const char *agent, const char *dir, const char *focus, long ttl) {
    Plane *p = plane_resolve(dir);
    if (!p) return legacy_update(agent, dir, focus, ttl);
    agent_require(p, agent);
    if (g_enforce && ttl <= 0) die("enforcement mode needs a positive ttl (got %ld)", ttl);   /* the strict agent record reader refuses ttl 0 */
    Txn *t = txn_begin(p, 1); txn_prune(t); import_legacy(t);
    if (agent_in_use(t, agent)) { txn_end(t, 0); return 2; }
    agent_set(t, agent, focus, ttl);
    txn_end(t, 1);
    printf("SCENT %s in %s: %s (ttl %lds)\n", agent, p->abs, focus, ttl);
    return 0;
}
static int cmd_whisper(const char *from, const char *dir, const char *to, const char *msg, const char *prio, const char *tf) {
    if (prio && *prio && strcmp(prio, "low") && strcmp(prio, "normal") && strcmp(prio, "high") && strcmp(prio, "critical")) die("priority must be low|normal|high|critical");
    Plane *p = plane_resolve(dir);
    if (!p) return legacy_whisper(from, dir, to, msg, prio, tf);
    agent_require(p, from);
    Txn *t = txn_begin(p, 1); txn_prune(t); import_legacy(t);
    whisper_add(dir_rec(t, p->rel)->root, from, to, msg, prio, tf);
    txn_end(t, 1);
    printf("WHISPER %s -> %s in %s\n", from, to && strcmp(to, "-") ? to : "(broadcast)", p->abs);
    return 0;
}
static int cmd_close(const char *agent, const char *dir, const char *target, const char *action, const char *msg) {
    static const char *ok[] = { "create", "modify", "delete", "audit", "test", "build", NULL };
    int good = 0; for (int i = 0; ok[i]; i++) if (!strcmp(ok[i], action)) good = 1;
    if (!good) die("action must be create|modify|delete|audit|test|build");
    Plane *p = plane_resolve(dir);
    if (!p) return legacy_close(agent, dir, target, action, msg);
    agent_require(p, agent);
    char *key = target_key(p, target, p->rel), *td = key_dir(key);
    Txn *t = txn_begin(p, 1); txn_prune(t); import_legacy(t);
    if (agent_in_use(t, agent)) { txn_end(t, 0); return 2; }
    Rec *tr = dir_rec(t, td);
    J *lk = jobj_of(tr->root, "locks"), *cur = jget(lk, key);
    const char *intent = "";
    if (cur) {
        const char *h = jstrval(cur, "holder");
        if (h && strcmp(h, agent)) { printf("REFUSED: %s is held by %s, not %s\n", key, h, agent); txn_end(t, 1); return 2; }
        if (jstrval(cur, "intent")) intent = jstrval(cur, "intent");
    }
    history_add(tr->root, agent, action, key, intent);
    if (cur) jdel(lk, key);
    if (!agent_has_lock(t, agent)) agent_rec(t, agent)->dead = 1;
    if (msg && *msg) whisper_add(tr->root, agent, NULL, msg, "normal", key);
    txn_end(t, 1);
    printf("CLOSED %s in %s by %s (%s)%s\n", key, p->top, agent, action, cur ? "" : " [no lock was held]");
    return 0;
}
/* check <agent> <dir> <target> [--generation N] (crumb924; the pre-write guard the session bridge calls).
 * Read-only: a shared fcntl lock on <root>/.lock (never created) for a consistent read; nothing is created, swept,
 * pruned or written. The leases on target and on every ancestor key (up to "." = the whole repository) are judged
 * with the strict schema in enforcement mode (lenient otherwise; malformed = exit 1 either way). Exit 0 only when a
 * valid lease on target or an ancestor is held by exactly <agent>, no other agent holds a valid lease on target or
 * an ancestor, and (when given) the nearest such lease has generation N and key K. Generations are counted per key,
 * so a bare number is ambiguous across keys (an ancestor lease can carry the same number later); a writer that
 * re-checks a token passes both --key and --generation, exactly as printed on the HELD line. Exit 2 otherwise. */
static int cmd_check(const char *agent, const char *dir, const char *target, int has_want, unsigned long long want, const char *want_key) {
    Plane *p = plane_resolve(dir);
    if (!p) die("check needs a git repository: %s", dir);
    agent_require(p, agent);
    char *key = target_key(p, target, p->rel);
    int fd = root_lock(p->root, 0);
    if (fd < 0 && store_used(p))   /* crumb924 B4: an initialized store without its lock is broken, not empty */
        die("STORE_LOCK_MISSING: coordination root %s is in use (layout %d%s) but has no .lock; refusing to report a lease without a consistent read (check never creates the lock)", p->root, p->layout, g_enforce ? ", enforcement mode" : "");
    ident_gate(&p->id, p->root, 0);   /* again under the lock: the root may have been swapped meanwhile */
    if (read_layout(p->root) != p->layout) die("STORE_LAYOUT_CHANGED: coordination root %s changed layout while this command ran (store-init); retry", p->root);
    long now = now_epoch();
    const char *mine_key = NULL, *other_key = NULL, *exp_key = NULL; Lease mine, other, gone;
    memset(&mine, 0, sizeof mine); memset(&other, 0, sizeof other); memset(&gone, 0, sizeof gone);
    char *k = xstrdup(key), *loaded_path = NULL; J *rec = NULL;
    for (;;) {
        char *kd = key_dir(k), *path = dir_path(p, kd);
        if (!loaded_path || strcmp(loaded_path, path)) {
            check_real_parents(p->root, path);
            size_t len = 0; char *txt = read_bounded(path, MAX_RECORD_BYTES, &len);
            rec = txt && strlen(txt) == len ? jparse(txt) : NULL;
            if (txt && (!rec || rec->t != JOBJ)) die("%s is not valid JSON; fix or move it aside", path);
            if (rec && g_enforce) dir_record_strict(path, rec, kd);
            J *lk0 = jget(rec, "locks");
            if (lk0 && lk0->t != JOBJ) die("MALFORMED_RECORD: %s: \"locks\" is not an object; refusing", path);
            loaded_path = path;
        }
        J *e = jget(jget(rec, "locks"), k);
        if (e) {
            Lease l; const char *why = lease_parse(e, g_enforce, &l);
            if (why) malformed(loaded_path, k, why);
            int valid = now - l.acq <= l.ttl;   /* now - acquired_at == ttl is still valid; ttl + 1 is expired */
            if (!valid) { if (!exp_key) { exp_key = xstrdup(k); gone = l; } }
            else if (!strcmp(l.holder, agent)) { if (!mine_key) { mine_key = xstrdup(k); mine = l; } }
            else if (!other_key) { other_key = xstrdup(k); other = l; }
        }
        if (!strcmp(k, ".")) break;
        char *up = strchr(k, '/') ? dir_of(k) : xstrdup(".");
        free(k); k = up; free(kd);
    }
    if (fd >= 0) close(fd);
    char ex[21];
    if (other_key) {
        iso_of(other.acq + other.ttl, ex);
        printf("REFUSED held-by %s %s key %s generation %llu expires %s\n", other.holder, key, other_key, other.gen, ex);
        return 2;
    }
    if (mine_key) {
        iso_of(mine.acq + mine.ttl, ex);
        if (want_key && strcmp(mine_key, want_key)) { printf("REFUSED key %s!=%s %s generation %llu by %s expires %s\n", mine_key, want_key, key, mine.gen, agent, ex); return 2; }
        if (has_want && mine.gen != want) { printf("REFUSED generation %llu!=%llu %s key %s by %s expires %s\n", mine.gen, want, key, mine_key, agent, ex); return 2; }
        printf("HELD %s by %s key %s generation %llu expires %s\n", key, agent, mine_key, mine.gen, ex);
        return 0;
    }
    if (exp_key) {
        iso_of(gone.acq + gone.ttl, ex);
        printf("REFUSED expired %s key %s holder %s generation %llu expired %s\n", key, exp_key, gone.holder, gone.gen, ex);
        return 2;
    }
    printf("REFUSED absent %s (no lease on it or any ancestor)\n", key);
    return 2;
}
static void print_agent(const J *e, const char *name) {
    long u = parse_iso(jstrval(e, "updated_at")), age = u < 0 ? -1 : now_epoch() - u;
    printf("  agent   %-16s branch %s  focus: %s  heartbeat %lds ago  [%s]\n", name, sv(e, "branch"), sv(e, "focus"), age, sv(e, "worktree"));
}
static int cmd_sniff(const char *agent, const char *dir) {   /* SPEC 5.1 + RFC-0002 */
    Plane *p = plane_resolve(dir);
    if (!p) {
        int r = legacy_sniff(agent, dir);
        printf("shared coordination: none (not a git repository)\n");
        return r;
    }
    agent_require(p, agent);
    char *cp = pjoin(p->abs, ".crumb"), *txt = slurp(cp); J *c = txt ? jparse(txt) : NULL;
    printf("sniff %s as %s\n", p->abs, agent);
    if (c) {
        J *inv = jget(c, "invariants");
        printf("  .crumb: %s | %s\n", jstrval(c, "name") ? jstrval(c, "name") : "?", jstrval(c, "purpose") ? jstrval(c, "purpose") : "(legacy format)");
        if (inv && inv->t == JARR) for (size_t i = 0; i < inv->n; i++) if (inv->v[i]->t == JSTR) printf("  invariant: %s\n", inv->v[i]->s);
    } else printf("  no .crumb here\n");
    Txn *t = txn_begin(p, 0); txn_prune(t); import_legacy(t);   /* read side: merged in memory, never saved */
    printf("shared coordination: ACTIVE\n  common root: %s\n", p->root);
    if (p->layout == 2) printf("  repository: %s (layout 2, id from %s)\n", p->repo_id, p->repo_src);
    printf("  this worktree: %s [%s %s]\nACTIVE AGENTS\n", p->top, p->branch, p->head);
    int any = 0;
    for (size_t i = 0; i < t->n; i++) if (t->r[i]->agent && !t->r[i]->dead && jget(t->r[i]->root, "updated_at")) { print_agent(t->r[i]->root, sv(t->r[i]->root, "agent")); any = 1; }
    if (!any) printf("  (none)\n");
    printf("LOCKS\n"); any = 0;
    for (size_t i = 0; i < t->n; i++) if (!t->r[i]->agent) {
        J *lk = jget(t->r[i]->root, "locks");
        if (lk && lk->t == JOBJ) for (size_t k = 0; k < lk->n; k++) { print_lock(lk->k[k], lk->v[k]); any = 1; }
    }
    if (!any) printf("  (none)\n");
    printf("OTHER WORKTREES\n");
    char *wl = run_git_full(p->abs, "worktree list --porcelain"), *save = NULL;
    int shown = 0;
    for (char *ln = strtok_r(wl, "\n", &save); ln; ) {
        if (strncmp(ln, "worktree ", 9)) { ln = strtok_r(NULL, "\n", &save); continue; }
        char *wt = xstrdup(ln + 9), *br = xstrdup("(detached)");
        while ((ln = strtok_r(NULL, "\n", &save)) && strncmp(ln, "worktree ", 9)) if (!strncmp(ln, "branch refs/heads/", 18)) br = xstrdup(ln + 18);
        char rp[PATH_MAX];
        if (strcmp(wt, p->top) && !(realpath(wt, rp) && !strcmp(rp, p->top))) {
            printf("  %s [%s]: ", wt, br); shown = 1;
            int na = 0;
            for (size_t i = 0; i < t->n; i++) if (t->r[i]->agent && !t->r[i]->dead && !strcmp(sv(t->r[i]->root, "worktree"), wt)) { printf("%s%s", na++ ? ", " : "agent ", sv(t->r[i]->root, "agent")); }
            if (!na) printf("no agents");
            int nc = 0;
            for (size_t i = 0; i < t->n; i++) if (!t->r[i]->agent) {
                J *lk = jget(t->r[i]->root, "locks");
                if (lk && lk->t == JOBJ) for (size_t k = 0; k < lk->n; k++) {
                    const char *kk = lk->k[k];
                    int in = !strcmp(p->rel, ".") || (!strncmp(kk, p->rel, strlen(p->rel)) && kk[strlen(p->rel)] == '/');
                    if (in && !strcmp(sv(lk->v[k], "worktree"), wt)) printf("%s%s", nc++ ? ", " : "; CONFLICT: ", kk);
                }
            }
            if (!nc) printf("; conflicts: none");
            printf("\n");
        }
    }
    if (!shown) printf("  (none)\n");
    printf("WHISPERS\n");
    J *wh = jget(dir_rec(t, p->rel)->root, "whispers"); any = 0;
    if (wh && wh->t == JARR) for (size_t i = 0; i < wh->n; i++) {
        const char *to = jstrval(wh->v[i], "to"), *from = jstrval(wh->v[i], "from");
        if (to && strcmp(to, agent)) continue;
        printf("  whisper %s -> %s: %s  [%s%s%s]\n", from ? from : "?", to ? to : "all", sv(wh->v[i], "message"), sv(wh->v[i], "timestamp"), jstrval(wh->v[i], "priority") ? " " : "", sv(wh->v[i], "priority")); any = 1;
    }
    if (!any) printf("  (none)\n");
    txn_end(t, 0);
    return 0;
}
static int g_skip_local;
static int shared_list(Plane *p) {   /* returns number of directories shown */
    Txn *t = txn_begin(p, 0); txn_prune(t);
    int n = 0;
    for (size_t i = 0; i < t->n; i++) if (!t->r[i]->agent) {
        const char *rel = sv(t->r[i]->root, "directory");
        if (strcmp(p->rel, ".") && strncmp(rel, p->rel, strlen(p->rel))) continue;
        J *lk = jget(t->r[i]->root, "locks"), *wh = jget(t->r[i]->root, "whispers");
        if (!((lk && lk->n) || (wh && wh->n))) continue;
        n++; printf("%s\n", rel);
        if (lk && lk->t == JOBJ) for (size_t k = 0; k < lk->n; k++) print_lock(lk->k[k], lk->v[k]);
        show_local(rel, t->r[i]->root, NULL);
    }
    for (size_t i = 0; i < t->n; i++) if (t->r[i]->agent && !t->r[i]->dead && jget(t->r[i]->root, "updated_at")) print_agent(t->r[i]->root, sv(t->r[i]->root, "agent"));
    txn_end(t, 0);
    return n;
}

/* ---------- tree walk ---------- */
static int skip_name(const char *n) {
    return n[0] == '.' || !strcmp(n, "target") || !strcmp(n, "node_modules") || !strcmp(n, "build") || !strcmp(n, "dist") || !strcmp(n, "vendor") || !strcmp(n, "evidence") || !strcmp(n, "__pycache__");
}
static int is_src(const char *n) {
    static const char *ext[] = { "c", "h", "cc", "cpp", "hpp", "S", "s", "rs", "mojo", "sh", NULL };
    const char *dot = strrchr(n, '.');
    if (!dot || dot == n) return !strcmp(n, "Makefile");
    for (int i = 0; ext[i]; i++) if (!strcmp(dot + 1, ext[i])) return 1;
    return 0;
}
static int cmpp(const void *a, const void *b) { return strcmp(*(char *const *)a, *(char *const *)b); }
static int nested_repo(const char *path) { char *g = pjoin(path, ".git"); struct stat st; int r = lstat(g, &st) == 0; free(g); return r; }

typedef struct Node { char *path, *rel, *name; char **files; size_t nf; struct Node **sub; size_t ns; int src; } Node;
static char **g_ign; static size_t g_nign;
static void load_ignore(const char *root) {   /* <root>/.crumbignore: one relative directory per line, '#' comments */
    char *p = pjoin(root, ".crumbignore"), *txt = slurp(p);
    if (!txt) return;
    for (char *l = strtok(txt, "\n"); l; l = strtok(NULL, "\n")) {
        size_t n = strlen(l); while (n && (l[n - 1] == '/' || l[n - 1] == '\r' || l[n - 1] == ' ')) l[--n] = 0;
        if (!n || l[0] == '#') continue;
        g_ign = xrealloc(g_ign, (g_nign + 1) * sizeof *g_ign); g_ign[g_nign++] = xstrdup(l);
    }
}
static int ignored_rel(const char *rel) {
    for (size_t i = 0; i < g_nign; i++) if (!strcmp(rel, g_ign[i])) return 1;
    return 0;
}
/* D10: a .crumbignore entry excludes that directory and everything below it from compile/verify/status.
   Its files still count toward the enclosing crumb's source tree (so a change there is still noticed upstairs),
   but no .crumb under it is ever read as a child or rewritten. Needed for trees guarded by immutability
   checks (omega evidence/, physics nvrm and m16). */
static int ignored_subtree(const char *rel) {
    for (size_t i = 0; i < g_nign; i++) {
        size_t n = strlen(g_ign[i]);
        if (!strncmp(rel, g_ign[i], n) && (rel[n] == 0 || rel[n] == '/')) return 1;
    }
    return 0;
}
static void reset_ignore(void) { for (size_t i = 0; i < g_nign; i++) free(g_ign[i]); free(g_ign); g_ign = NULL; g_nign = 0; }

/* Traversal policy for compile/verify/status (issue sovereign-core#355). ONE function decides whether a directory
 * takes part, and find_crumbs, the children list and the tracked-crumb pass all call it, so the three commands cannot
 * disagree. A directory is excluded when it is (a) under a .crumbignore entry (D10), (b) a directory git itself
 * ignores and that holds no tracked file (build output such as target/ listed in .gitignore), or (c) a conventional
 * generated-output directory (target, node_modules, __pycache__) that holds no tracked file. A directory with any
 * tracked file is real source and always takes part (except via .crumbignore), so no integrity check is weakened. */
static char *shq(const char *s); static char *cap_cmd(const char *cmd, size_t *len);   /* defined with the compiler below */
static char **g_trk; static size_t g_ntrk;    /* tracked paths (git ls-files) */
static char **g_gign; static size_t g_ngign;  /* wholly untracked+ignored directories, "dir/" */
static void policy_load(const char *top) {
    for (size_t i = 0; i < g_ntrk; i++) free(g_trk[i]);
    for (size_t i = 0; i < g_ngign; i++) free(g_gign[i]);
    free(g_trk); free(g_gign); g_trk = NULL; g_gign = NULL; g_ntrk = g_ngign = 0;
    char *tq = shq(top), cmd[PATH_MAX + 96]; size_t n; char *raw;
    snprintf(cmd, sizeof cmd, "git -C %s ls-files -z 2>/dev/null", tq);
    raw = cap_cmd(cmd, &n);
    for (char *s = raw; s < raw + n; s += strlen(s) + 1) { g_trk = xrealloc(g_trk, (g_ntrk + 1) * sizeof *g_trk); g_trk[g_ntrk++] = xstrdup(s); }
    snprintf(cmd, sizeof cmd, "git -C %s ls-files -z --others --ignored --exclude-standard --directory 2>/dev/null", tq);
    raw = cap_cmd(cmd, &n);
    for (char *s = raw; s < raw + n; s += strlen(s) + 1) {
        size_t l = strlen(s); if (!l || s[l - 1] != '/') continue;   /* directories only */
        g_gign = xrealloc(g_gign, (g_ngign + 1) * sizeof *g_gign); g_gign[g_ngign++] = xstrdup(s);
    }
}
static int tracked_under(const char *rel) {
    size_t n = strlen(rel);
    for (size_t i = 0; i < g_ntrk; i++) if (!strncmp(g_trk[i], rel, n) && g_trk[i][n] == '/') return 1;
    return 0;
}
static int skip_generated_dir(const char *rel) {   /* rel: repo-relative directory, no trailing slash */
    if (ignored_subtree(rel)) return 1;
    const char *b = strrchr(rel, '/'); b = b ? b + 1 : rel;
    if (!strcmp(b, ".git")) return 1;
    if (tracked_under(rel)) return 0;
    size_t n = strlen(rel);
    for (size_t i = 0; i < g_ngign; i++) if (strlen(g_gign[i]) == n + 1 && !strncmp(g_gign[i], rel, n)) return 1;
    return !strcmp(b, "target") || !strcmp(b, "node_modules") || !strcmp(b, "__pycache__");
}
static Node *scan(const char *path, const char *rel, int isroot) {
    Node *n = xmalloc(sizeof *n); memset(n, 0, sizeof *n);
    n->path = xstrdup(path); n->rel = xstrdup(rel); n->name = xstrdup(base_of(path));
    DIR *d = opendir(path);
    if (!d) return n;
    char **names = NULL; size_t cnt = 0, cap = 0; struct dirent *e;
    while ((e = readdir(d))) {
        if (!strcmp(e->d_name, ".") || !strcmp(e->d_name, "..")) continue;
        if (cnt == cap) { cap = cap ? cap * 2 : 32; names = xrealloc(names, cap * sizeof *names); }
        names[cnt++] = xstrdup(e->d_name);
    }
    closedir(d);
    qsort(names, cnt, sizeof *names, cmpp);
    (void)isroot;
    for (size_t i = 0; i < cnt; i++) {
        char *full = pjoin(path, names[i]); struct stat st;
        if (lstat(full, &st) == 0) {
            if (S_ISDIR(st.st_mode)) {
                if (!skip_name(names[i]) && !nested_repo(full)) {
                    char *r = !strcmp(rel, ".") ? xstrdup(names[i]) : pjoin(rel, names[i]);
                    if (!ignored_rel(r)) {
                        n->sub = xrealloc(n->sub, (n->ns + 1) * sizeof *n->sub);
                        n->sub[n->ns++] = scan(full, r, 0);
                    }
                }
            } else if (S_ISREG(st.st_mode) && strcmp(names[i], ".crumb") && strcmp(names[i], ".crumb.local") && names[i][0] != '.') {
                n->files = xrealloc(n->files, (n->nf + 1) * sizeof *n->files);
                n->files[n->nf++] = xstrdup(names[i]);
                if (is_src(names[i])) n->src = 1;
            }
        }
        free(full);
    }
    return n;
}
static int qualifies(const Node *n, int depth) { return depth <= 1 || n->nf > 0; }

static char *run_git(const char *root, const char *args) {
    Buf q = {0}; bstr(&q, "'");
    for (const char *p = root; *p; p++) { if (*p == '\'') bstr(&q, "'\\''"); else bput(&q, p, 1); }
    bstr(&q, "'");
    size_t cn = q.n + strlen(args) + 32; char *cmd = xmalloc(cn);
    snprintf(cmd, cn, "git -C %s %s 2>/dev/null", q.p, args);
    FILE *f = popen(cmd, "r"); if (!f) return xstrdup("");
    char t[512]; size_t n = fread(t, 1, sizeof t - 1, f); t[n] = 0; pclose(f);
    while (n && (t[n - 1] == '\n' || t[n - 1] == '\r')) t[--n] = 0;
    return xstrdup(t);
}

typedef struct { int created, updated, unchanged, legacy, skipped_bad; int dry, verbose; J *git; } Stats;

static void seed_node(const Node *n, int depth, const char *anc_name, const char *anc_path, Stats *st) {
    int q = qualifies(n, depth);
    const char *next_name = anc_name, *next_path = anc_path;
    char *selfname = NULL, *nextpath = NULL;
    if (q) {
        char *cp = pjoin(n->path, ".crumb"), *txt = slurp(cp);
        J *c = txt ? jparse(txt) : NULL;
        const char *state = "unchanged";
        if (txt && (!c || c->t != JOBJ)) { st->skipped_bad++; printf("BAD-JSON %s (left untouched)\n", cp); goto after; }
        if (c && jget(c, "version") && !jget(c, "schema_version")) {   /* pre-RFC Atlas/spark-crumbs format */
            st->legacy++; if (st->verbose) printf("legacy   %s (left untouched)\n", cp); goto after;
        }
        char *before = c ? jdump(c) : xstrdup("");
        int fresh = !c; if (!c) c = jnew(JOBJ);
        char auto_purpose[PATH_MAX + 96];
        if (depth == 0) snprintf(auto_purpose, sizeof auto_purpose, "Repository root %s. Purpose not yet described by a human.", n->name);
        else snprintf(auto_purpose, sizeof auto_purpose, "Directory %s. Purpose not yet described by a human.", n->rel);
        J *oldext = jget(c, "extensions"), *seed = oldext ? jget(oldext, "seed") : NULL;
        const char *prev_auto = seed ? jstrval(seed, "purpose_auto") : NULL;
        if (!jget(c, "schema_version")) jset(c, "schema_version", jstr(SCHEMA));
        if (!jget(c, "name")) jset(c, "name", jstr(depth == 0 ? n->name : n->rel));
        if (!jget(c, "layer")) jset(c, "layer", jstr(depth == 0 ? "root" : n->rel));
        J *ext = NULL;
        const char *pur = jstrval(c, "purpose");
        if (!pur || (prev_auto && !strcmp(pur, prev_auto))) jset(c, "purpose", jstr(auto_purpose));  /* hand-written purpose is never touched */
        if (depth > 0 && !jget(c, "above")) {
            J *a = jnew(JOBJ); jset(a, "name", jstr(anc_name)); jset(a, "path", jstr(anc_path)); jset(c, "above", a);
        }
        if (n->ns) {
            J *b = jarr_of(c, "below");
            for (size_t i = 0; i < n->ns; i++) {
                int have = 0;
                for (size_t k = 0; k < b->n; k++) { const char *nm = b->v[k]->t == JSTR ? b->v[k]->s : jstrval(b->v[k], "name"); if (nm && !strcmp(nm, n->sub[i]->name)) have = 1; }
                if (!have) { J *e = jnew(JOBJ); jset(e, "name", jstr(n->sub[i]->name)); jset(e, "role", jstr("")); jpush(b, e); }
            }
        }
        ext = jobj_of(c, "extensions");
        J *ns = jnew(JOBJ);            /* tool-owned block; everything else in the file is the humans' */
        jset(ns, "purpose_auto", jstr(auto_purpose));
        J *fl = jnew(JARR);
        for (size_t i = 0; i < n->nf && i < 50; i++) jpush(fl, jstr(n->files[i]));
        jset(ns, "files", fl);
        if (depth == 0 && st->git) jset(ns, "git", st->git);
        jset(ext, "seed", ns);
        if (!jget(ext, "owner_lane")) jset(ext, "owner_lane", jstr(""));
        char *after_txt = jdump(c);
        if (fresh) { st->created++; state = "created"; }
        else if (strcmp(before, after_txt)) { st->updated++; state = "updated"; }
        else st->unchanged++;
        if (strcmp(state, "unchanged")) { if (!st->dry) spit(cp, after_txt); if (st->verbose || st->dry) printf("%-8s %s\n", state, cp); }
        else if (st->verbose) printf("%-8s %s\n", state, cp);
    }
after:
    if (q) { selfname = depth == 0 ? n->name : n->rel; next_name = selfname; next_path = ".."; }
    else { nextpath = pjoin(anc_path, ".."); next_path = nextpath; }
    for (size_t i = 0; i < n->ns; i++) seed_node(n->sub[i], depth + 1, next_name, next_path, st);
}
static void ensure_gitignore(const char *root, Stats *st) {
    char *g = pjoin(root, ".gitignore"), *txt = slurp(g);
    if (!nested_repo(root)) return;
    if (txt) { for (char *l = strtok(xstrdup(txt), "\n"); l; l = strtok(NULL, "\n")) if (!strcmp(l, ".crumb.local") || !strcmp(l, "/.crumb.local") || !strcmp(l, "**/.crumb.local")) return; }
    printf("gitignore: adding .crumb.local to %s\n", g);
    if (st->dry) return;
    Buf b = {0}; bstr(&b, txt ? txt : "");
    if (b.n && b.p[b.n - 1] != '\n') bstr(&b, "\n");
    bstr(&b, ".crumb.local\n");
    spit(g, b.p);
}
static int cmd_seed(const char *root, int dry, int verbose) {
    char *r = absdir(root);
    Stats st; memset(&st, 0, sizeof st); st.dry = dry; st.verbose = verbose;
    if (nested_repo(r)) {
        J *g = jnew(JOBJ);
        jset(g, "remote", jstr(run_git(r, "remote get-url origin")));
        jset(g, "branch", jstr(run_git(r, "branch --show-current")));
        jset(g, "head", jstr(run_git(r, "rev-parse --short HEAD")));
        st.git = g;
    }
    load_ignore(r);
    Node *tree = scan(r, ".", 1);
    seed_node(tree, 0, tree->name, "..", &st);
    ensure_gitignore(r, &st);
    printf("seed %s%s: created %d, updated %d, unchanged %d, legacy-skipped %d, bad-json %d\n", r, dry ? " (dry run)" : "", st.created, st.updated, st.unchanged, st.legacy, st.skipped_bad);
    return 0;
}
static int cmd_create(const char *dir, const char *name, const char *purpose, const char *layer) {
    char *d = absdir(dir), *cp = pjoin(d, ".crumb");
    struct stat s; if (stat(cp, &s) == 0) { printf("EXISTS %s (use seed to refresh, edit by hand to change fields)\n", cp); return 2; }
    J *c = jnew(JOBJ);
    jset(c, "schema_version", jstr(SCHEMA)); jset(c, "name", jstr(name));
    if (layer && *layer) jset(c, "layer", jstr(layer));
    jset(c, "purpose", jstr(purpose));
    spit(cp, jdump(c));
    printf("CREATED %s\n", cp);
    return 0;
}

typedef struct { int n_crumb, n_local, bad; } Tot;
static void walk_list(const char *path, const char *rel, int depth, int validate, Tot *t) {
    char *cp = pjoin(path, ".crumb"), *lp = pjoin(path, ".crumb.local"), *txt = slurp(cp);
    if (txt) {
        t->n_crumb++;
        J *c = jparse(txt);
        if (validate) {
            if (!c || c->t != JOBJ) { printf("INVALID %s: not a JSON object\n", cp); t->bad++; }
            else if (jget(c, "version") && !jget(c, "schema_version")) printf("LEGACY  %s (pre-RFC format, not validated)\n", cp);
            else {
                const char *sv = jstrval(c, "schema_version");
                if (!sv || strcmp(sv, SCHEMA) || !jstrval(c, "name") || !jstrval(c, "purpose")) { printf("INVALID %s: needs schema_version \"%s\", name, purpose\n", cp, SCHEMA); t->bad++; }
            }
        }
    }
    if (!validate && !g_skip_local && slurp(lp)) {
        Local l = local_open(path);   /* read side: sweep applied in memory, never saved */
        J *sc = jget(l.root, "active_scents"), *lk = jget(l.root, "locks"), *wh = jget(l.root, "whispers");
        if ((sc && sc->n) || (lk && lk->n) || (wh && wh->n)) { t->n_local++; printf("%s\n", rel); show_local(path, l.root, NULL); }
    }
    DIR *d = opendir(path); if (!d) return;
    char **names = NULL; size_t cnt = 0, cap = 0; struct dirent *e;
    while ((e = readdir(d))) {
        if (e->d_name[0] == '.' || skip_name(e->d_name)) continue;
        if (cnt == cap) { cap = cap ? cap * 2 : 32; names = xrealloc(names, cap * sizeof *names); }
        names[cnt++] = xstrdup(e->d_name);
    }
    closedir(d);
    qsort(names, cnt, sizeof *names, cmpp);
    for (size_t i = 0; i < cnt; i++) {
        char *full = pjoin(path, names[i]); struct stat st;
        if (lstat(full, &st) == 0 && S_ISDIR(st.st_mode) && !nested_repo(full)) {
            char *r = !strcmp(rel, ".") ? xstrdup(names[i]) : pjoin(rel, names[i]);
            walk_list(full, r, depth + 1, validate, t);
        }
    }
}


/* ---------- backfill: reconstruct history that crumbs would have recorded ---------- */
#include <ctype.h>
#include <glob.h>
#define LEDGER_CAP 20      /* entries (commits) kept in the committed .crumb extensions.provenance */
#define DOC_CAP 200        /* commits per directory in docs/crumbs/BACKFILL.md */

typedef struct { char hash[41]; char *date, *author, *subj; long pr; } Commit;
typedef struct { char *rel; int *c; size_t n, cap; } DirAcc;
typedef struct { char *lane, *note, *ref; long pr; char *repo, *sha; int id; } LaneRef;

static Commit *g_commits; static size_t g_nc, g_ncap;
static DirAcc **g_dirs; static size_t g_ndirs, g_dcap;
static LaneRef *g_lr; static size_t g_nlr, g_lrcap;

static DirAcc *dir_acc(const char *rel) {
    for (size_t i = 0; i < g_ndirs; i++) if (!strcmp(g_dirs[i]->rel, rel)) return g_dirs[i];
    if (g_ndirs == g_dcap) { g_dcap = g_dcap ? g_dcap * 2 : 256; g_dirs = xrealloc(g_dirs, g_dcap * sizeof *g_dirs); }
    DirAcc *d = xmalloc(sizeof *d); memset(d, 0, sizeof *d); d->rel = xstrdup(rel);
    return g_dirs[g_ndirs++] = d;
}
static void dir_add(const char *rel, size_t ci) {
    DirAcc *d = dir_acc(rel);
    if (d->n && d->c[d->n - 1] == (int)ci) return;
    if (d->n == d->cap) { d->cap = d->cap ? d->cap * 2 : 8; d->c = xrealloc(d->c, d->cap * sizeof *d->c); }
    d->c[d->n++] = (int)ci;
}
static long pr_of(const char *subj) {
    const char *p = NULL, *q = subj;
    while ((q = strstr(q, "(#"))) { p = q; q += 2; }
    if (p && isdigit((unsigned char)p[2])) return atol(p + 2);
    if (!strncmp(subj, "Merge pull request #", 20)) return atol(subj + 20);
    return 0;
}
static void load_commits(const char *root, const char *since) {
    Buf q = {0}; bstr(&q, "'");
    for (const char *p = root; *p; p++) { if (*p == '\'') bstr(&q, "'\\''"); else bput(&q, p, 1); }
    bstr(&q, "'");
    Buf cmd = {0}; bstr(&cmd, "git -c core.quotepath=false -C "); bstr(&cmd, q.p);
    bstr(&cmd, " log --first-parent -m --name-only --format=%x01%H%x1f%cI%x1f%an%x1f%s");
    if (since && strchr(since, '\'')) die("--since must not contain a quote");
    if (since) { bstr(&cmd, " --since='"); bstr(&cmd, since); bstr(&cmd, "'"); }
    bstr(&cmd, " 2>/dev/null");
    FILE *f = popen(cmd.p, "r"); if (!f) return;
    char *line = NULL; size_t lc = 0; ssize_t len; long cur = -1;
    while ((len = getline(&line, &lc, f)) > 0) {
        while (len && (line[len - 1] == '\n' || line[len - 1] == '\r')) line[--len] = 0;
        if (line[0] == 1) {
            cur = -1;
            if (g_nc == g_ncap) { g_ncap = g_ncap ? g_ncap * 2 : 256; g_commits = xrealloc(g_commits, g_ncap * sizeof *g_commits); }
            Commit *c = &g_commits[g_nc]; memset(c, 0, sizeof *c);
            char *h = line + 1, *d = strchr(h, 31); if (!d) continue; *d++ = 0;
            char *a = strchr(d, 31); if (!a) continue; *a++ = 0;
            char *s = strchr(a, 31); if (!s) continue; *s++ = 0;
            snprintf(c->hash, sizeof c->hash, "%s", h);
            c->date = xstrdup(d); c->author = xstrdup(a); c->subj = xstrdup(s); c->pr = pr_of(s);
            cur = (long)g_nc++;
        } else if (len && cur >= 0) {
            char *dir = xstrdup(line);
            for (;;) {   /* every ancestor directory of the file, root last */
                char *sl = strrchr(dir, '/');
                if (!sl) { dir_add(".", (size_t)cur); break; }
                *sl = 0; dir_add(dir, (size_t)cur);
            }
            free(dir);
        }
    }
    pclose(f); free(line);
}
static const char *repo_alias(const char *tok, size_t n) {
    static const struct { const char *a, *full; } al[] = { {"omega","omega"}, {"aienos","aienos"}, {"arch","aien-architecture"}, {"aien-architecture","aien-architecture"}, {"physics","physics"}, {NULL,NULL} };
    for (int i = 0; al[i].a; i++) if (strlen(al[i].a) == n && !strncmp(tok, al[i].a, n)) return al[i].full;
    return NULL;
}
static void lr_add(const char *lane, const char *note, const char *ref, long pr, const char *repo, const char *sha, int id) {
    if (g_nlr == g_lrcap) { g_lrcap = g_lrcap ? g_lrcap * 2 : 128; g_lr = xrealloc(g_lr, g_lrcap * sizeof *g_lr); }
    LaneRef *r = &g_lr[g_nlr++]; r->lane = xstrdup(lane); r->note = xstrdup(note); r->ref = xstrdup(ref); r->pr = pr; r->repo = repo ? xstrdup(repo) : NULL; r->sha = sha ? xstrdup(sha) : NULL; r->id = id;
}
static void parse_lane_file(const char *path) {
    FILE *f = fopen(path, "r"); if (!f) return;
    const char *bn = base_of(path), *fl = strstr(bn, "lane"); char filelane[24] = "";
    if (fl && isdigit((unsigned char)fl[4])) { int k = 0; fl += 4; while (isdigit((unsigned char)*fl) && k < 8) { filelane[k++] = *fl++; } filelane[k] = 0; }
    char *line = NULL; size_t lc = 0; ssize_t len; static int idc = 0; int id;
    while ((len = getline(&line, &lc, f)) > 0) {
        while (len && (line[len - 1] == '\n' || line[len - 1] == '\r')) line[--len] = 0;
        char lane[24] = ""; const char *L = strstr(line, "Lane ");
        if (L && isdigit((unsigned char)L[5])) { int k = 0; const char *p = L + 5; while (isdigit((unsigned char)*p) && k < 8) lane[k++] = *p++; lane[k] = 0; }
        if (!lane[0]) snprintf(lane, sizeof lane, "%s", filelane);
        if (!lane[0]) continue;
        char lname[32]; snprintf(lname, sizeof lname, "lane%s", lane);
        char note[200]; const char *s = line; while (*s == '-' || *s == ' ' || *s == '*') s++;
        snprintf(note, sizeof note, "%s", s);
        id = ++idc;
        for (const char *p = line; *p; p++) {
            if (*p == '#' && isdigit((unsigned char)p[1]) && p > line) {   /* explicit repo#N only; bare #N is ambiguous */
                const char *e = p; if (e > line + 1 && e[-1] == ' ') e--; const char *rp = e;
                while (e > line && (isalnum((unsigned char)e[-1]) || e[-1] == '-')) e--;
                const char *full = repo_alias(e, (size_t)(rp - e));
                if (full) lr_add(lname, note, bn, atol(p + 1), full, NULL, id);
            }
            if (isxdigit((unsigned char)*p) && (p == line || !isalnum((unsigned char)p[-1]))) {
                const char *e = p; int dig = 0, let = 0;
                while (isxdigit((unsigned char)*e) && !isupper((unsigned char)*e)) { if (isdigit((unsigned char)*e)) dig = 1; else let = 1; e++; }
                if (e == p) e = p + 1;
                size_t n = (size_t)(e - p);
                if (!isalnum((unsigned char)*e) && n >= 7 && n <= 40 && dig && let) { char sh[41]; memcpy(sh, p, n); sh[n] = 0; lr_add(lname, note, bn, 0, NULL, sh, id); }
                p = e - 1;
            }
        }
    }
    fclose(f); free(line);
}
static void load_lane_reports(const char *home) {
    char pat[PATH_MAX]; glob_t g;
    snprintf(pat, sizeof pat, "%s/handoffs/2026-10-01-push-lane*-report.md", home);
    if (!glob(pat, 0, NULL, &g)) { for (size_t i = 0; i < g.gl_pathc; i++) parse_lane_file(g.gl_pathv[i]); globfree(&g); }
    snprintf(pat, sizeof pat, "%s/handoffs/2026-10-01-next-major-push-orchestrator.md", home);
    parse_lane_file(pat);
}
static int lr_matches(const LaneRef *r, const Commit *c, const char *repo) {
    if (r->sha) return !strncmp(c->hash, r->sha, strlen(r->sha));
    return r->pr && c->pr == r->pr && r->repo && !strcmp(r->repo, repo);
}
static J *git_entry(const Commit *c) {
    J *e = jnew(JOBJ); char sh[8]; memcpy(sh, c->hash, 7); sh[7] = 0;
    jset(e, "source", jstr("backfill-git")); jset(e, "sha", jstr(sh)); jset(e, "timestamp", jstr(c->date));
    jset(e, "author", jstr(c->author)); jset(e, "subject", jstr(c->subj));
    if (c->pr) jset(e, "pr", jnum(c->pr));
    return e;
}
static J *lane_entry(const LaneRef *r, const Commit *c) {
    J *e = jnew(JOBJ); char sh[8]; memcpy(sh, c->hash, 7); sh[7] = 0;
    jset(e, "source", jstr("backfill-lane-report")); jset(e, "lane", jstr(r->lane)); jset(e, "sha", jstr(sh));
    if (c->pr) jset(e, "pr", jnum(c->pr));
    jset(e, "note", jstr(r->note)); jset(e, "ref", jstr(r->ref));
    return e;
}
static void mkdir_p(const char *path) {
    char *p = xstrdup(path);
    for (char *s = p + 1; *s; s++) if (*s == '/') { *s = 0; mkdir(p, 0777); *s = '/'; }
    mkdir(p, 0777); free(p);
}
typedef struct { Buf doc; int dirs, updated, unchanged, git_entries, lane_entries, truncated_dirs; } BfStats;

static void backfill_node(const Node *n, int depth, const char *repo, BfStats *st, int dry) {
    if (qualifies(n, depth)) {
        char *cp = pjoin(n->path, ".crumb"), *txt = slurp(cp);
        J *c = txt ? jparse(txt) : NULL;
        if (c && c->t == JOBJ && jget(c, "schema_version")) {
            DirAcc *d = NULL;
            for (size_t i = 0; i < g_ndirs; i++) if (!strcmp(g_dirs[i]->rel, n->rel)) d = g_dirs[i];
            char *before = jdump(c);
            J *ext = jget(c, "extensions"), *led = jnew(JARR), *prov = jnew(JOBJ);
            if (!ext || ext->t != JOBJ) ext = jobj_of(c, "extensions");
            size_t total = d ? d->n : 0; int doc_lines = 0;
            Buf sec = {0}; bstr(&sec, "");
            for (size_t k = 0; d && k < d->n && k < DOC_CAP; k++) {
                const Commit *cm = &g_commits[d->c[k]];
                if (k < LEDGER_CAP) { jpush(led, git_entry(cm)); st->git_entries++; }
                char ln[700]; snprintf(ln, sizeof ln, "- %.10s %.7s%s%s %s: %s [backfill-git]\n", cm->date, cm->hash, cm->pr ? " #" : "", "", cm->author, cm->subj);
                if (cm->pr) snprintf(ln, sizeof ln, "- %.10s %.7s #%ld %s: %s [backfill-git]\n", cm->date, cm->hash, cm->pr, cm->author, cm->subj);
                bstr(&sec, ln); doc_lines++;
                for (size_t r = 0; r < g_nlr; r++) {
                    if (!lr_matches(&g_lr[r], cm, repo)) continue;
                    int dup = 0; for (size_t r2 = 0; r2 < r; r2++) if (g_lr[r2].id == g_lr[r].id && lr_matches(&g_lr[r2], cm, repo)) dup = 1;
                    if (dup) continue;
                    if (k < LEDGER_CAP) { jpush(led, lane_entry(&g_lr[r], cm)); st->lane_entries++; }
                    snprintf(ln, sizeof ln, "  - %s (%s): %.160s [backfill-lane-report]\n", g_lr[r].lane, g_lr[r].ref, g_lr[r].note);
                    bstr(&sec, ln);
                }
            }
            jset(prov, "source", jstr("backfill"));
            jset(prov, "total_commits", jnum((long)total));
            jset(prov, "ledger_cap", jnum(LEDGER_CAP));
            jset(prov, "entries", led);
            if (total > DOC_CAP) st->truncated_dirs++;
            if (total) jset(ext, "provenance", prov); else jdel(ext, "provenance");
            if (doc_lines) {
                char hd[PATH_MAX + 64]; snprintf(hd, sizeof hd, "\n## %s\n\n%zu commit(s) touched this tree%s\n\n", n->rel, total, total > DOC_CAP ? "; showing newest 200 (older truncated)" : "");
                bstr(&st->doc, hd); bstr(&st->doc, sec.p);
            }
            st->dirs++;
            char *after = jdump(c);
            if (strcmp(before, after)) { st->updated++; if (!dry) spit(cp, after); } else st->unchanged++;
        }
    }
    for (size_t i = 0; i < n->ns; i++) backfill_node(n->sub[i], depth + 1, repo, st, dry);
}
static int cmd_backfill(const char *root, const char *since, int dry) {
    char *r = absdir(root);
    char *home = getenv("HOME"); if (!home) home = "";
    load_ignore(r);
    Node *tree = scan(r, ".", 1);
    char *remote = run_git(r, "remote get-url origin"), *repo = xstrdup(base_of(remote));
    size_t rl = strlen(repo); if (rl > 4 && !strcmp(repo + rl - 4, ".git")) repo[rl - 4] = 0;
    if (!nested_repo(r)) {   /* not a repo: only lane reports, recorded on the root directory */
        load_lane_reports(home);
        char *cp = pjoin(r, ".crumb"), *txt = slurp(cp); J *c = txt ? jparse(txt) : NULL;
        if (!c || !jget(c, "schema_version")) { printf("backfill %s: no spec-format .crumb at root (run seed or create first)\n", r); return 1; }
        char *before = jdump(c); J *ext = jobj_of(c, "extensions"), *prov = jnew(JOBJ), *led = jnew(JARR);
        glob_t g; char pat[PATH_MAX]; snprintf(pat, sizeof pat, "%s/2026-10-01-push-lane*-report.md", r);
        int cnt = 0;
        if (!glob(pat, 0, NULL, &g)) for (size_t i = 0; i < g.gl_pathc; i++) {
            struct stat s; if (stat(g.gl_pathv[i], &s)) continue;
            const char *bn = base_of(g.gl_pathv[i]), *l = strstr(bn, "lane"); char lane[32]; snprintf(lane, sizeof lane, "lane%d", l ? atoi(l + 4) : 0);
            char ts[21]; struct tm tm; gmtime_r(&s.st_mtime, &tm); strftime(ts, sizeof ts, "%Y-%m-%dT%H:%M:%SZ", &tm);
            J *e = jnew(JOBJ); jset(e, "source", jstr("backfill-lane-report")); jset(e, "lane", jstr(lane)); jset(e, "ref", jstr(bn)); jset(e, "timestamp", jstr(ts));
            jpush(led, e); cnt++;
        }
        jset(prov, "source", jstr("backfill")); jset(prov, "entries", led); jset(ext, "provenance", prov);
        char *after = jdump(c);
        if (strcmp(before, after) && !dry) spit(cp, after);
        printf("backfill %s (not a git repo): %d lane report(s) recorded, %s\n", r, cnt, strcmp(before, after) ? "changed" : "unchanged");
        return 0;
    }
    load_commits(r, since);
    load_lane_reports(home);
    BfStats st; memset(&st, 0, sizeof st);
    Buf hd = {0}; bstr(&hd, "# Crumb backfill (generated by `crumb backfill`, do not edit by hand)\n\nHistory that crumbs would have recorded, reconstructed from git first-parent history and from the 2026-10-01 lane reports. Every entry is marked `backfill-git` or `backfill-lane-report`: none of it is a live whisper. A commit is listed under every directory it touched, newest first, up to 200 per directory. Lane entries are report lines that mention a commit or PR (mentions, not verified authorship); they attach only where a report names `<repo>#<PR>` or a commit SHA that exists here.\n");
    st.doc = hd;
    backfill_node(tree, 0, repo, &st, dry);
    char *docp = pjoin(r, "docs/crumbs/BACKFILL.md");
    char *old = slurp(docp);
    if (!old || strcmp(old, st.doc.p)) { if (!dry) { char *dd = pjoin(r, "docs/crumbs"); mkdir_p(dd); spit(docp, st.doc.p); } printf("BACKFILL.md: %s (%zu bytes)\n", old ? "updated" : "created", st.doc.n); }
    else printf("BACKFILL.md: unchanged\n");
    printf("backfill %s (%s, %zu commits%s): %d crumb dirs, updated %d, unchanged %d, ledger git entries %d, lane entries %d, dirs truncated in doc %d\n", r, repo, g_nc, since ? ", since given" : "", st.dirs, st.updated, st.unchanged, st.git_entries, st.lane_entries, st.truncated_dirs);
    return 0;
}
static void usage(void);
/* ---------- RFC-0002 section 7: crumb explain ---------- */
#define EXPL_COMMITS 10
#define EXPL_WHISPERS 5
static void print_strs(const char *label, const J *a, int max) {   /* array of strings, or a single string */
    if (!a) return;
    if (a->t == JSTR) { printf("  %s: %s\n", label, a->s); return; }
    if (a->t != JARR) return;
    for (size_t i = 0; i < a->n && (int)i < max; i++) {
        if (a->v[i]->t == JSTR) printf("  %s: %s\n", label, a->v[i]->s);
        else { char *d = jdump(a->v[i]); d[strcspn(d, "\n")] = 0; printf("  %s: %s\n", label, d); }
    }
}
static J *load_crumb(const char *dir) { char *cp = pjoin(dir, ".crumb"), *txt = slurp(cp); J *c = txt ? jparse(txt) : NULL; return c && c->t == JOBJ ? c : NULL; }
/* does a continuation path entry (e.g. "tools/crumb/", "repo tools/crumb/.crumb") mention rel? */
static int path_mentions(const char *entry, const char *rel) {
    if (!strcmp(rel, ".")) return 1;
    size_t rl = strlen(rel);
    for (const char *s = entry; (s = strstr(s, rel)); s++) {
        int before = s == entry || s[-1] == ' ' || s[-1] == '/' || s[-1] == '"';
        char a = s[rl];
        int after = !a || a == '/' || a == ' ' || a == '"';
        if (before && after) return 1;
    }
    /* entry is an ancestor of rel (owner of the parent directory) */
    size_t el = strlen(entry);
    while (el && entry[el - 1] == '/') el--;
    return el > 0 && el < rl && !strncmp(entry, rel, el) && rel[el] == '/';
}
static int cont_matches(const J *c, const char *rel) {
    J *co = jget(c, "coordination");
    static const char *keys[] = { "scope", "owned", "owned_paths", NULL };
    if (!co || co->t != JOBJ) return 0;
    for (int k = 0; keys[k]; k++) {
        J *a = jget(co, keys[k]);
        if (a && a->t == JARR) for (size_t i = 0; i < a->n; i++) if (a->v[i]->t == JSTR && path_mentions(a->v[i]->s, rel)) return 1;
    }
    return 0;
}
static const char *cont_when(const J *c) {
    J *id = jget(c, "identity");
    const char *s = id ? jstrval(id, "sealed_at") : NULL;
    if (!s && id) s = jstrval(id, "created_at");
    return s ? s : "";
}
static char *shq(const char *s);
static int cmd_explain(const char *target) {
    char r[PATH_MAX];
    if (!realpath(target, r)) die("no such file or directory: %s", target);
    struct stat st; if (stat(r, &st)) die("cannot stat %s", target);
    char *abs = xstrdup(r), *dir = S_ISDIR(st.st_mode) ? xstrdup(r) : dir_of(r);
    Plane *p = plane_resolve(dir);
    const char *env = getenv("CRUMB_COORD_ROOT");
    char *top = p ? p->top : NULL, *rel = NULL;
    if (p) {
        size_t tl = strlen(top);
        rel = abs[tl] ? xstrdup(abs + tl + 1) : xstrdup(".");
    } else rel = xstrdup(base_of(abs));
    char *store = p ? p->store : (env && *env ? env_store(env) : NULL);   /* no repository: env-only identity */
    printf("EXPLAIN %s\n  repository path: %s\n", abs, rel);

    /* 1. nearest .crumb */
    printf("== NEAREST CRUMB ==\n");
    char *d = xstrdup(dir), *nearest = NULL; J *nc = NULL;
    for (;;) {
        if ((nc = load_crumb(d))) { nearest = xstrdup(d); break; }
        if (top && !strcmp(d, top)) break;
        char *up = dir_of(d); if (!strcmp(up, d) || !strcmp(up, ".")) break;
        if (!*up) { free(up); up = xstrdup("/"); if (!strcmp(d, "/")) break; }
        free(d); d = up;
    }
    if (nc) {
        printf("  file: %s/.crumb\n  name: %s\n  layer: %s\n  purpose: %s\n", nearest, sv(nc, "name"), sv(nc, "layer"), sv(nc, "purpose"));
        J *inv = jget(nc, "invariants"); if (inv) print_strs("invariant", inv, 50); else printf("  invariant: (none)\n");
        J *ex = jget(nc, "exports"); if (ex) print_strs("export", ex, 50); else printf("  export: (none)\n");
        J *rl = jget(nc, "related"); if (rl) print_strs("related", rl, 50); else printf("  related: (none)\n");
    } else printf("  (no .crumb found at or above this path)\n");

    /* 2. inherited invariants */
    printf("== INHERITED INVARIANTS ==\n");
    int any = 0;
    if (nearest) {
        char *u = dir_of(nearest);
        while (strcmp(u, nearest) && strcmp(u, ".")) {
            if (top && strlen(u) < strlen(top)) break;
            J *pc = load_crumb(u);
            if (pc) { J *inv = jget(pc, "invariants"); if (inv && inv->t == JARR) for (size_t i = 0; i < inv->n; i++) if (inv->v[i]->t == JSTR) { printf("  from %s/.crumb: %s\n", u, inv->v[i]->s); any = 1; } }
            if (top && !strcmp(u, top)) break;
            char *nx = dir_of(u); if (!strcmp(nx, u)) break; u = nx;
        }
    }
    if (!any) printf("  (none)\n");

    /* 3. shared coordination */
    printf("== SHARED COORDINATION ==\n");
    if (p) {
        Txn *t = txn_begin(p, 0); txn_prune(t);
        char *dr = !strcmp(rel, ".") ? xstrdup(".") : (S_ISDIR(st.st_mode) ? xstrdup(rel) : dir_of(rel));
        any = 0;
        for (size_t i = 0; i < t->n; i++) if (t->r[i]->agent && !t->r[i]->dead && jget(t->r[i]->root, "updated_at")) { print_agent(t->r[i]->root, sv(t->r[i]->root, "agent")); any = 1; }
        if (!any) printf("  agents: (none)\n");
        any = 0;
        for (size_t i = 0; i < t->n; i++) if (!t->r[i]->agent) {
            J *lk = jget(t->r[i]->root, "locks");
            if (lk && lk->t == JOBJ) for (size_t k = 0; k < lk->n; k++) {
                const char *kk = lk->k[k]; char *kd = key_dir(kk);
                if (!strcmp(dr, ".") || !strcmp(kd, dr) || path_mentions(kk, rel)) { print_lock(kk, lk->v[k]); any = 1; }
            }
        }
        if (!any) printf("  locks: (none)\n");
        J *wh = jget(dir_rec(t, dr)->root, "whispers"); any = 0;
        if (wh && wh->t == JARR) for (size_t i = wh->n > EXPL_WHISPERS ? wh->n - EXPL_WHISPERS : 0; i < wh->n; i++) {
            printf("  whisper %s -> %s: %s  [%s]\n", sv(wh->v[i], "from"), jstrval(wh->v[i], "to") ? jstrval(wh->v[i], "to") : "all", sv(wh->v[i], "message"), sv(wh->v[i], "timestamp")); any = 1;
        }
        if (!any) printf("  whispers: (none)\n");
        txn_end(t, 0);
    } else if (store) printf("  coordination root %s (no repository)\n", store);
    else printf("  shared coordination: none (not a git repository)\n");

    /* 4. commits */
    printf("== RECENT COMMITS ==\n");
    if (p) {
        char *quoted = shq(rel);
        size_t qlen = strlen(quoted) + 64;
        char *q = xmalloc(qlen);
        snprintf(q, qlen, "log --oneline -%d -- %s", EXPL_COMMITS, quoted);
        char *lg = run_git_full(top, q);
        free(q); free(quoted);
        if (*lg) { for (char *s = strtok(lg, "\n"); s; s = strtok(NULL, "\n")) printf("  %s\n", s); } else printf("  (no commits touch this path)\n");
    } else printf("  (not a git repository)\n");
    if (nc) {
        J *ex = jget(nc, "extensions"), *pv = ex && ex->t == JOBJ ? jget(ex, "provenance") : NULL, *en = pv && pv->t == JOBJ ? jget(pv, "entries") : NULL;
        if (en && en->t == JARR) for (size_t i = 0; i < en->n && i < EXPL_COMMITS; i++) {
            const char *sh = jstrval(en->v[i], "sha"); int dup = 0;
            for (size_t j = 0; sh && j < i; j++) if (!strcmp(sv(en->v[j], "sha"), sh)) dup = 1;
            if (sh && !dup) printf("  named in .crumb: %s %s\n", sh, sv(en->v[i], "subject"));
        }
    }

    /* 5. evidence references */
    printf("== EVIDENCE REFERENCES ==\n");
    any = 0;
    if (nc) {
        J *ex = jget(nc, "extensions");
        if (ex && ex->t == JOBJ) {
            J *ev = jget(ex, "evidence");
            if (ev) { print_strs("crumb evidence", ev, 20); any = 1; }
            J *pv = jget(ex, "provenance"), *en = pv && pv->t == JOBJ ? jget(pv, "entries") : NULL;
            if (en && en->t == JARR) for (size_t i = 0; i < en->n && i < EXPL_COMMITS; i++) { long pr = jlong(en->v[i], "pr", 0); int dup = 0; for (size_t j = 0; j < i; j++) if (jlong(en->v[j], "pr", 0) == pr) dup = 1; if (pr && !dup) { printf("  crumb pr: #%ld (%s)\n", pr, sv(en->v[i], "sha")); any = 1; } }
        }
    }
    /* 6. continuations */
    J *best = NULL; char *bestf = NULL; int nmatch = 0;
    if (store) {
        char **f = NULL; size_t n = 0; char *cd = pjoin(store, "continuations");
        collect_json(cd, &f, &n);
        for (size_t i = 0; i < n; i++) {
            char *txt = read_bounded(f[i], MAX_RECORD_BYTES, NULL); J *c = txt ? jparse(txt) : NULL;
            if (g_enforce && (!c || c->t != JOBJ)) die("%s is not valid JSON; refusing (enforcement mode never skips unreadable state)", f[i]);
            if (!c || c->t != JOBJ || !jget(c, "identity") || !cont_matches(c, rel)) continue;
            nmatch++;
            J *ev = jget(c, "evidence");
            if (ev && ev->t == JOBJ) {
                static const char *ek[] = { "commits", "prs", "receipts", NULL };
                for (int k = 0; ek[k]; k++) { J *a = jget(ev, ek[k]); if (a && a->t == JARR) for (size_t j = 0; j < a->n && j < 10; j++) if (a->v[j]->t == JSTR) { printf("  continuation %s %s: %s\n", sv(jget(c, "identity"), "checkpoint_id"), ek[k], a->v[j]->s); any = 1; } }
                J *ts = jget(ev, "tests");
                if (ts && ts->t == JARR) for (size_t j = 0; j < ts->n && j < 10; j++) { printf("  continuation test: %s -> %s\n", sv(ts->v[j], "name"), sv(ts->v[j], "result")); any = 1; }
            }
            if (!best || strcmp(cont_when(c), cont_when(best)) > 0) { best = c; bestf = f[i]; }
        }
    }
    if (!any) printf("  (none)\n");
    printf("== NEWEST CONTINUATION ==\n");
    if (!best) printf("  (none touches this path)\n");
    else {
        J *id = jget(best, "identity"), *st2 = jget(best, "state"), *items = st2 && st2->t == JOBJ ? jget(st2, "items") : st2;
        printf("  id: %s  sealed: %s  by: %s  (%d matching, showing 1)\n  file: %s\n  reason: %s\n", sv(id, "checkpoint_id"), cont_when(best), sv(id, "created_by"), nmatch, bestf, sv(id, "reason"));
        J *rv = jget(best, "revalidation"); if (rv) printf("  revalidation: %s\n", sv(rv, "status"));
        if (items && items->t == JARR) for (size_t i = 0; i < items->n; i++) printf("  [%s] %s\n", sv(items->v[i], "tag"), sv(items->v[i], "claim"));
    }
    return 0;
}

/* ---------- RFC-0002 section 7: checkpoint / resume (thin wrappers around cc.sh) ---------- */
static char *cc_path(void) {
    const char *e = getenv("CRUMB_CC");
    if (e && *e) return xstrdup(e);
    const char *h = getenv("HOME");
    if (!h || !*h) die("HOME is not set; set CRUMB_CC to the path of cc.sh");
    size_t n = strlen(h) + 64; char *s = xmalloc(n);
    snprintf(s, n, "%s/.claude/skills/checkpoint/scripts/cc.sh", h); return s;
}
static void cc_env(Plane *p) {   /* records must land in <coordination root>/continuations (layout 2: the namespace's) */
    const char *env = getenv("CRUMB_COORD_ROOT");
    if (p && p->layout == 2) {
        char *cs = pjoin(p->store, "continuations");
        setenv("CRUMB_COORD_ROOT", p->root, 1); setenv("CC_STORE", cs, 1); setenv("CRUMB_REPO_ID", p->repo_id, 1);
    } else if (p) setenv("CRUMB_COORD_ROOT", p->store, 1);
    else if (!(env && *env)) die("no repository context: run inside a git checkout or set CRUMB_COORD_ROOT");
    else { char *st = env_store(env); if (strcmp(st, env)) { char *cs = pjoin(st, "continuations"); setenv("CC_STORE", cs, 1); } }
    char self[PATH_MAX]; ssize_t n = readlink("/proc/self/exe", self, sizeof self - 1);
    if (n > 0 && !getenv("CRUMB_BIN")) { self[n] = 0; setenv("CRUMB_BIN", self, 1); }
}
static char *cc_script(void) {
    char *cc = cc_path();
    if (access(cc, X_OK) != 0) die("cc.sh not found or not executable at %s (the checkpoint skill; set CRUMB_CC to override)", cc);
    return cc;
}
static char *shq(const char *s) { Buf q = {0}; bstr(&q, "'"); for (; *s; s++) { if (*s == '\'') bstr(&q, "'\\''"); else bput(&q, s, 1); } bstr(&q, "'"); return q.p; }
static int cmd_checkpoint(int a, char **v) {
    const char *agent = NULL, *reason = NULL, *seal = NULL;
    for (int i = 0; i < a; i++) {
        if (!strcmp(v[i], "--reason") && i + 1 < a) reason = v[++i];
        else if (!strcmp(v[i], "--seal") && i + 1 < a) seal = v[++i];
        else if (!agent && v[i][0] != '-') agent = v[i];
        else usage();
    }
    if (!agent && !seal) usage();
    Plane *p = plane_resolve("."); cc_env(p);
    char *cc = cc_script(); const char *ag = agent ? agent : (getenv("CC_AGENT") ? getenv("CC_AGENT") : "claude");
    setenv("CC_AGENT", ag, 1);
    if (seal) execl(cc, cc, "seal", seal, ag, (char *)NULL);
    else {
        char *top = p ? p->top : absdir(".");
        Buf cmd = {0}; char *q1 = shq(cc), *q2 = shq(agent), *q3 = shq(top);
        bstr(&cmd, q1); bstr(&cmd, " new "); bstr(&cmd, q2); bstr(&cmd, " "); bstr(&cmd, q3);
        FILE *f = popen(cmd.p, "r"); if (!f) die("cannot run %s", cc);
        char out[PATH_MAX + 2]; size_t n = fread(out, 1, sizeof out - 1, f); out[n] = 0;
        if (pclose(f) != 0 || !n) die("cc.sh new failed");
        out[strcspn(out, "\n")] = 0;
        if (reason) {
            Buf c2 = {0}; char *qr = shq(reason), *qo = shq(out);
            bstr(&c2, "tmp=$(mktemp) && jq --arg r "); bstr(&c2, qr); bstr(&c2, " '.identity.reason=$r' "); bstr(&c2, qo);
            bstr(&c2, " > \"$tmp\" && mv \"$tmp\" "); bstr(&c2, qo);
            if (system(c2.p) != 0) die("could not record the reason (jq missing?)");
        }
        printf("%s\n", out);
        fprintf(stderr, "fill in the record, then: crumb checkpoint --seal <id> %s\n", agent);
        return 0;
    }
    die("cannot exec %s: %s", cc, strerror(errno));
    return 1;
}
static int cmd_resume(const char *id) {
    Plane *p = plane_resolve("."); cc_env(p);
    char *cc = cc_script();
    execl(cc, cc, "resume", id, (char *)NULL);
    die("cannot exec %s: %s", cc, strerror(errno));
    return 1;
}

/* decimal seconds, 0..MAX_TTL, nothing else (no sign, no spaces, no overflow): the writer accepts exactly what every
 * reader accepts (crumb924 B5; the strict reader refuses ttl_seconds above MAX_TTL, enforcement also refuses 0) */
static long ttl_arg(const char *s, long dflt) {
    if (!s) return dflt;
    long v = 0;
    for (const char *c = s; *c; c++) {
        if (*c < '0' || *c > '9' || v > (MAX_TTL - (*c - '0')) / 10) die("bad ttl: %s (expected 0..%ld seconds)", s, MAX_TTL);
        v = v * 10 + (*c - '0');
    }
    if (!*s) die("bad ttl: (empty) (expected 0..%ld seconds)", MAX_TTL);
    return v;
}
/* ---------- RFC-0003: Crumb Compiler (C port of crumb-compile.sh; design decisions D1-D9 there are binding) ----------
 * compile/verify/status: hand-authored kernel stays, everything structural is generated bottom-up into
 * .crumb extensions.generated with Merkle digests. Output is byte-identical to the shell reference. */
static char *xstrndup_(const char *s, size_t n) { char *p = xmalloc(n + 1); memcpy(p, s, n); p[n] = 0; return p; }
typedef struct { uint32_t h[8]; uint64_t len; unsigned char buf[64]; size_t nb; } Sha;
static const uint32_t K256[64] = {
 0x428a2f98,0x71374491,0xb5c0fbcf,0xe9b5dba5,0x3956c25b,0x59f111f1,0x923f82a4,0xab1c5ed5,0xd807aa98,0x12835b01,0x243185be,0x550c7dc3,0x72be5d74,0x80deb1fe,0x9bdc06a7,0xc19bf174,
 0xe49b69c1,0xefbe4786,0x0fc19dc6,0x240ca1cc,0x2de92c6f,0x4a7484aa,0x5cb0a9dc,0x76f988da,0x983e5152,0xa831c66d,0xb00327c8,0xbf597fc7,0xc6e00bf3,0xd5a79147,0x06ca6351,0x14292967,
 0x27b70a85,0x2e1b2138,0x4d2c6dfc,0x53380d13,0x650a7354,0x766a0abb,0x81c2c92e,0x92722c85,0xa2bfe8a1,0xa81a664b,0xc24b8b70,0xc76c51a3,0xd192e819,0xd6990624,0xf40e3585,0x106aa070,
 0x19a4c116,0x1e376c08,0x2748774c,0x34b0bcb5,0x391c0cb3,0x4ed8aa4a,0x5b9cca4f,0x682e6ff3,0x748f82ee,0x78a5636f,0x84c87814,0x8cc70208,0x90befffa,0xa4506ceb,0xbef9a3f7,0xc67178f2 };
#define ROR(x, n) (((x) >> (n)) | ((x) << (32 - (n))))
static void sha_block(Sha *s, const unsigned char *p) {
    uint32_t w[64], a, b, c, d, e, f, g, h;
    for (int i = 0; i < 16; i++) w[i] = (uint32_t)p[4*i] << 24 | (uint32_t)p[4*i+1] << 16 | (uint32_t)p[4*i+2] << 8 | p[4*i+3];
    for (int i = 16; i < 64; i++) {
        uint32_t s0 = ROR(w[i-15], 7) ^ ROR(w[i-15], 18) ^ (w[i-15] >> 3), s1 = ROR(w[i-2], 17) ^ ROR(w[i-2], 19) ^ (w[i-2] >> 10);
        w[i] = w[i-16] + s0 + w[i-7] + s1;
    }
    a = s->h[0]; b = s->h[1]; c = s->h[2]; d = s->h[3]; e = s->h[4]; f = s->h[5]; g = s->h[6]; h = s->h[7];
    for (int i = 0; i < 64; i++) {
        uint32_t t1 = h + (ROR(e, 6) ^ ROR(e, 11) ^ ROR(e, 25)) + ((e & f) ^ (~e & g)) + K256[i] + w[i];
        uint32_t t2 = (ROR(a, 2) ^ ROR(a, 13) ^ ROR(a, 22)) + ((a & b) ^ (a & c) ^ (b & c));
        h = g; g = f; f = e; e = d + t1; d = c; c = b; b = a; a = t1 + t2;
    }
    s->h[0] += a; s->h[1] += b; s->h[2] += c; s->h[3] += d; s->h[4] += e; s->h[5] += f; s->h[6] += g; s->h[7] += h;
}
static void sha_init(Sha *s) {
    static const uint32_t iv[8] = { 0x6a09e667,0xbb67ae85,0x3c6ef372,0xa54ff53a,0x510e527f,0x9b05688c,0x1f83d9ab,0x5be0cd19 };
    memcpy(s->h, iv, sizeof iv); s->len = 0; s->nb = 0;
}
static void sha_add(Sha *s, const void *data, size_t n) {
    const unsigned char *p = data; s->len += n;
    while (n) {
        size_t k = 64 - s->nb; if (k > n) k = n;
        memcpy(s->buf + s->nb, p, k); s->nb += k; p += k; n -= k;
        if (s->nb == 64) { sha_block(s, s->buf); s->nb = 0; }
    }
}
static void sha_hex(Sha *s, char *out) {   /* out: 65 bytes */
    uint64_t bits = s->len * 8; unsigned char pad = 0x80, z = 0, lb[8];
    sha_add(s, &pad, 1); while (s->nb != 56) sha_add(s, &z, 1);
    for (int i = 0; i < 8; i++) lb[i] = (unsigned char)(bits >> (56 - 8 * i));
    sha_add(s, lb, 8);
    for (int i = 0; i < 8; i++) snprintf(out + 8 * i, 9, "%08x", s->h[i]);
}

static void jsort(J *j) {   /* jq -S: object keys in codepoint (= UTF-8 byte) order, recursively */
    if (j->t == JARR) { for (size_t i = 0; i < j->n; i++) jsort(j->v[i]); return; }
    if (j->t != JOBJ) return;
    for (size_t i = 1; i < j->n; i++) {   /* insertion sort on parallel arrays (stable, small) */
        char *k = j->k[i]; J *v = j->v[i]; size_t m = i;
        while (m > 0 && strcmp(j->k[m - 1], k) > 0) { j->k[m] = j->k[m - 1]; j->v[m] = j->v[m - 1]; m--; }
        j->k[m] = k; j->v[m] = v;
    }
    for (size_t i = 0; i < j->n; i++) jsort(j->v[i]);
}
static void jcompact(const J *j, Buf *b) {   /* jq -c */
    switch (j->t) {
    case JARR: bput(b, "[", 1); for (size_t i = 0; i < j->n; i++) { if (i) bput(b, ",", 1); jcompact(j->v[i], b); } bput(b, "]", 1); break;
    case JOBJ: bput(b, "{", 1); for (size_t i = 0; i < j->n; i++) { if (i) bput(b, ",", 1); jescape(b, j->k[i]); bput(b, ":", 1); jcompact(j->v[i], b); } bput(b, "}", 1); break;
    default: jprint(j, b, 0);
    }
}
static char *jcompact_s(const J *j) { Buf b = {0}; bstr(&b, ""); jcompact(j, &b); return b.p; }

static char *cap_cmd(const char *cmd, size_t *len) {   /* all output bytes of a shell command, NUL-safe */
    FILE *f = popen(cmd, "r"); Buf b = {0}; bstr(&b, "");
    if (!f) { if (len) *len = 0; return b.p; }
    char t[8192]; size_t n;
    while ((n = fread(t, 1, sizeof t, f)) > 0) bput(&b, t, n);
    pclose(f); if (len) *len = b.n; return b.p;
}
static void chomp(char *s) { size_t n = strlen(s); while (n && s[n - 1] == '\n') s[--n] = 0; }

typedef struct { char *blob, *path; } CFile;
static int cfcmp(const void *a, const void *b) { return strcmp(((const CFile *)a)->path, ((const CFile *)b)->path); }
typedef struct { char *dir, *dig; } DDig;
typedef struct { CFile *f; size_t nf; DDig *dd; size_t ndd, cdd; char *top; } Comp;

static int is_crumb_name(const char *path) {   /* D1: every .crumb and .crumb.local */
    const char *b = strrchr(path, '/'); b = b ? b + 1 : path;
    return !strcmp(b, ".crumb") || !strcmp(b, ".crumb.local");
}
static int is_evidence(const char *p) {
    size_t n = strlen(p);
    if (n >= 13 && !strcmp(p + n - 13, ".receipt.json")) return 1;
    static const char *w[] = { "evidence/", "receipts/", NULL };
    for (int k = 0; w[k]; k++) for (const char *s = p; (s = strstr(s, w[k])); s++) if (s == p || s[-1] == '/') return 1;
    return 0;
}
static void comp_load_files(Comp *c) {   /* D2: tracked files of the working tree, blob ids via git hash-object */
    size_t n; char *raw;
    char *tq = shq(c->top), cmd[PATH_MAX + 64];
    snprintf(cmd, sizeof cmd, "git -C %s ls-files -z 2>/dev/null", tq);
    raw = cap_cmd(cmd, &n);
    Buf present = {0}; bstr(&present, ""); size_t np = 0; char **pp = NULL, *s = raw;
    while (s < raw + n) {
        size_t l = strlen(s);
        if (l && !is_crumb_name(s)) {
            char *full = pjoin(c->top, s); struct stat st;
            if (stat(full, &st) == 0 && S_ISREG(st.st_mode)) { pp = xrealloc(pp, (np + 1) * sizeof *pp); pp[np++] = xstrdup(s); bstr(&present, s); bput(&present, "\n", 1); }
            free(full);
        }
        s += l + 1;
    }
    c->nf = 0; c->f = NULL;
    if (np) {
        char tmpl[] = "/tmp/crumb-compile-XXXXXX"; int fd = mkstemp(tmpl);
        if (fd < 0) die("cannot create temp file");
        if (write(fd, present.p, present.n) != (ssize_t)present.n) die("temp write failed");
        close(fd);
        snprintf(cmd, sizeof cmd, "git -C %s hash-object --stdin-paths < %s 2>/dev/null", tq, tmpl);
        char *hs = cap_cmd(cmd, NULL); unlink(tmpl);
        char *sv2 = NULL, *ln = strtok_r(hs, "\n", &sv2);
        c->f = xmalloc(np * sizeof *c->f);
        for (size_t i = 0; i < np; i++) {
            if (!ln) die("git hash-object returned too few ids");
            c->f[i].blob = xstrdup(ln); c->f[i].path = pp[i]; ln = strtok_r(NULL, "\n", &sv2);
        }
        c->nf = np;
        qsort(c->f, c->nf, sizeof *c->f, cfcmp);
    }
}
static const char *dig_of(Comp *c, const char *dir) { for (size_t i = 0; i < c->ndd; i++) if (!strcmp(c->dd[i].dir, dir)) return c->dd[i].dig; return NULL; }
static void dig_set(Comp *c, const char *dir, const char *dig) {
    if (c->ndd == c->cdd) { c->cdd = c->cdd ? c->cdd * 2 : 16; c->dd = xrealloc(c->dd, c->cdd * sizeof *c->dd); }
    c->dd[c->ndd].dir = xstrdup(dir); c->dd[c->ndd++].dig = xstrdup(dig);
}
static size_t utf8_prefix(const char *s, int cps) {   /* byte length of the first cps codepoints (jq .[0:n]) */
    size_t i = 0; int k = 0;
    while (s[i] && k < cps) { i++; while (((unsigned char)s[i] & 0xC0) == 0x80) i++; k++; }
    return i;
}
static int sstrcmp(const void *a, const void *b) { return strcmp(*(char *const *)a, *(char *const *)b); }
/* Children of a crumb directory = nearest crumbed descendants (D7 amendment). One traversal policy with find_crumbs. */
typedef struct { char *rel; char *name; } Kid;   /* rel: repo-relative directory; name: path relative to the parent crumb dir */
static int kidcmp(const void *a, const void *b) { return strcmp(((const Kid *)a)->name, ((const Kid *)b)->name); }
static void collect_kids(Comp *c, const char *dir, const char *prefix, Kid **out, size_t *n, size_t *cap) {
    int root = !strcmp(dir, "."); char *dfull = root ? xstrdup(c->top) : pjoin(c->top, dir); DIR *dp = opendir(dfull);
    char **names = NULL; size_t nn = 0;
    if (dp) { struct dirent *e; while ((e = readdir(dp))) if (strcmp(e->d_name, ".") && strcmp(e->d_name, "..")) { names = xrealloc(names, (nn + 1) * sizeof *names); names[nn++] = xstrdup(e->d_name); } closedir(dp); }
    qsort(names, nn, sizeof *names, sstrcmp);
    for (size_t i = 0; i < nn; i++) {
        char *kd = root ? xstrdup(names[i]) : pjoin(dir, names[i]), *kf = pjoin(c->top, kd); struct stat st;
        if (lstat(kf, &st) || !S_ISDIR(st.st_mode) || skip_generated_dir(kd)) { free(kd); free(kf); continue; }   /* D10 + #355 */
        char *kc = pjoin(kf, ".crumb"); struct stat sb; int has = !stat(kc, &sb) && S_ISREG(sb.st_mode);
        size_t pl = strlen(prefix), nl = strlen(names[i]); char *name = xmalloc(pl + nl + 2); memcpy(name, prefix, pl); memcpy(name + pl, names[i], nl + 1);
        if (has) {
            if (*n == *cap) { *cap = *cap ? *cap * 2 : 16; *out = xrealloc(*out, *cap * sizeof **out); }
            (*out)[*n].rel = kd; (*out)[(*n)++].name = name;
        } else { name[pl + nl] = '/'; name[pl + nl + 1] = 0; collect_kids(c, kd, name, out, n, cap); free(name); free(kd); }
        free(kf); free(kc);
    }
    free(names); free(dfull);
}
static J *comp_object(Comp *c, const char *d, char *dig_out) {   /* the generated object, without stamps */
    int root = !strcmp(d, "."); size_t pl = root ? 0 : strlen(d) + 1;
    char pre[PATH_MAX]; if (!root) snprintf(pre, sizeof pre, "%s/", d); else pre[0] = 0;
    Sha st, ev; sha_init(&st); sha_init(&ev); long nfiles = 0, nev = 0; (void)pl;
    for (size_t i = 0; i < c->nf; i++) {
        if (!root && strncmp(c->f[i].path, pre, strlen(pre))) continue;
        sha_add(&st, c->f[i].blob, strlen(c->f[i].blob)); sha_add(&st, " ", 1); sha_add(&st, c->f[i].path, strlen(c->f[i].path)); sha_add(&st, "\n", 1);
        nfiles++;
        if (is_evidence(c->f[i].path)) { sha_add(&ev, c->f[i].blob, strlen(c->f[i].blob)); sha_add(&ev, "\n", 1); nev++; }
    }
    char sth[65], evh[65]; sha_hex(&st, sth); sha_hex(&ev, evh);
    /* D5: semantic kernel as hand written */
    char *cp = pjoin(d, ".crumb"), *full = pjoin(c->top, cp), *txt = slurp(full); J *cr = txt ? jparse(txt) : NULL;
    J *sem = jnew(JOBJ);
    if (cr && cr->t == JOBJ) {
        static const char *ks[] = { "purpose", "layer", "invariants", "exports", "related", "boundaries", NULL };
        for (int k = 0; ks[k]; k++) { J *v = jget(cr, ks[k]); if (v && v->t != JNULL) jset(sem, ks[k], v); }
    }
    jsort(sem); char *semc = jcompact_s(sem);
    /* D7 (amended 2026-10-11, orphan crumbs): children = the NEAREST crumbed descendants. The walk descends through
     * directories that hold no .crumb (same traversal policy as find_crumbs: skip_generated_dir, lstat, no symlinks),
     * so every compiled crumb is reachable from the root digest and deleting any .crumb stales its nearest crumbed
     * ancestor. A deep child is named by its path relative to this crumb's directory ("archive/plans"). */
    Kid *kids_v = NULL; size_t nn = 0, kcap = 0; collect_kids(c, d, "", &kids_v, &nn, &kcap);
    qsort(kids_v, nn, sizeof *kids_v, kidcmp);
    J *kids = jnew(JARR); Sha crs; sha_init(&crs);
    for (size_t i = 0; i < nn; i++) {
        char *kd = kids_v[i].rel, *kc = pjoin(kd, ".crumb"), *kcf = pjoin(c->top, kc); const char *kname = kids_v[i].name;
        const char *kdig = dig_of(c, kd); char *kdig_own = NULL;
        if (!kdig) {   /* not compiled in this run: fall back to what the crumb says */
            char *kt = slurp(kcf); J *kj = kt ? jparse(kt) : NULL; J *x = kj ? jget(kj, "extensions") : NULL; x = x ? jget(x, "generated") : NULL;
            const char *g = x ? jstrval(x, "digest") : NULL; kdig = kdig_own = xstrdup(g ? g : "uncompiled");
        }
        char *kt = slurp(kcf); J *kj = kt ? jparse(kt) : NULL; const char *kp = kj ? jstrval(kj, "purpose") : NULL; if (!kp) kp = "";
        char *kpur = xstrdup(kp); kpur[utf8_prefix(kpur, 96)] = 0; chomp(kpur);
        char gq[PATH_MAX * 2 + 64], *kq = shq(kd); snprintf(gq, sizeof gq, "log -1 --format=%%h HEAD -- %s ':!**/.crumb'", kq);
        char *lc = run_git_full(c->top, gq); chomp(lc);
        J *o = jnew(JOBJ); jset(o, "name", jstr(kname)); jset(o, "digest", jstr(kdig)); jset(o, "purpose", jstr(kpur)); jset(o, "last_commit", jstr(lc));
        jpush(kids, o); sha_add(&crs, kdig, strlen(kdig)); sha_add(&crs, "\n", 1);
        (void)kdig_own;
    }
    char crh[65]; sha_hex(&crs, crh);
    Sha ds; sha_init(&ds); sha_add(&ds, semc, strlen(semc)); sha_add(&ds, sth, 64); sha_add(&ds, crh, 64); sha_add(&ds, evh, 64);
    char dgh[65]; sha_hex(&ds, dgh);   /* D3: content only, no stamps */
    strcpy(dig_out, dgh);
    J *g = jnew(JOBJ); char t[80];
    jset(g, "compiler", jstr("crumb-compile/1"));
    snprintf(t, sizeof t, "sha256:%s", sth); jset(g, "source_tree", jstr(t));
    jset(g, "files", jnum(nfiles)); jset(g, "children", kids);
    snprintf(t, sizeof t, "sha256:%s", crh); jset(g, "children_root", jstr(t));
    jset(g, "evidence_files", jnum(nev));
    snprintf(t, sizeof t, "sha256:%s", evh); jset(g, "evidence_root", jstr(t));
    snprintf(t, sizeof t, "sha256:%s", dgh); jset(g, "digest", jstr(t));
    jsort(g); return g;
}
/* D3a (added by the C port): children[].last_commit is derived from history and changes with every commit that
 * touches the child, exactly like the stamps of D3. It is written by compile but never decides STALE; otherwise a
 * PR could never pass verify (committing changes last_commit, which would need another compile, forever). */
static void strip_lc(J *g) { J *k = jget(g, "children"); if (k && k->t == JARR) for (size_t i = 0; i < k->n; i++) if (k->v[i]->t == JOBJ) jdel(k->v[i], "last_commit"); }
typedef struct { char *d; int depth; } CDir;
static int cdcmp(const void *a, const void *b) {
    const CDir *x = a, *y = b;
    if (x->depth != y->depth) return y->depth - x->depth;   /* deepest first (D4) */
    return strcmp(x->d, y->d);
}
static void find_crumbs(const char *top, const char *rel, CDir **out, size_t *n, size_t *cap) {
    char *full = *rel ? pjoin(top, rel) : xstrdup(top); DIR *dp = opendir(full); if (!dp) return;
    struct dirent *e;
    while ((e = readdir(dp))) {
        if (!strcmp(e->d_name, ".") || !strcmp(e->d_name, "..")) continue;
        char *r = *rel ? pjoin(rel, e->d_name) : xstrdup(e->d_name), *f = pjoin(top, r); struct stat st;
        if (lstat(f, &st) == 0) {
            if (S_ISDIR(st.st_mode) && skip_generated_dir(r)) { free(r); free(f); continue; }   /* D10 + #355 */
            if (!strcmp(e->d_name, ".crumb") && !S_ISDIR(st.st_mode)) {
                if (*n == *cap) { *cap = *cap ? *cap * 2 : 32; *out = xrealloc(*out, *cap * sizeof **out); }
                (*out)[*n].d = *rel ? xstrdup(rel) : xstrdup("."); (*n)++;
            } else if (S_ISDIR(st.st_mode)) find_crumbs(top, r, out, n, cap);
        }
        free(r); free(f);
    }
    closedir(dp); free(full);
}

/* RFC-0003 amendment 1 (2026-10-18): generated data is derived on demand, never committed.
 * A repository opts in with "extensions": {"generated_policy": "on-demand"} in its ROOT .crumb (written once by
 * `crumb migrate`). Then every committed crumb holds only what a human writes; a committed extensions.generated
 * block is STALE (it is the roll-up that made two unrelated PRs rewrite the same root lines), compile strips it,
 * verify prints the root digest computed from the tree at HEAD, and `crumb digest` prints any generated block.
 * Without the marker the repository is legacy and every command behaves exactly as before the amendment. */
#define GEN_POLICY_KEY "generated_policy"
#define GEN_POLICY_ON_DEMAND "on-demand"
static const char *g_digest_dir = NULL;   /* mode 'd': repo-relative directory whose generated block to print */
static int root_on_demand(const char *top) {
    J *rc = load_crumb(top); J *x = rc ? jget(rc, "extensions") : NULL;
    const char *p = x && x->t == JOBJ ? jstrval(x, GEN_POLICY_KEY) : NULL;
    return p && !strcmp(p, GEN_POLICY_ON_DEMAND);
}
static void write_crumb(const char *full, J *cr) {   /* D9: key-sorted, temp file then rename */
    jsort(cr);
    char *out = jdump(cr), *tmp = xmalloc(strlen(full) + 32); snprintf(tmp, strlen(full) + 32, "%s.tmp.%ld", full, (long)getpid());
    FILE *f = fcreate(tmp, 0); if (!f) die("cannot write %s", tmp);
    if (fputs(out, f) < 0 || fclose(f) != 0) die("write failed: %s", tmp);
    if (rename(tmp, full)) die("rename failed: %s", full);
}

/* mode: 'c' compile, 'v' verify, 's' status, 'm' migrate (to on-demand), 'd' digest (print one generated block).
 * Returns number of stale crumbs; *total set. */
static int compile_engine(char mode, const char *root, int quiet, int *total_out, char *head_out) {
    Comp c; memset(&c, 0, sizeof c);
    char *rq = shq(root), cmd[PATH_MAX + 80]; snprintf(cmd, sizeof cmd, "git -C %s rev-parse --show-toplevel 2>/dev/null", rq);
    char *top = cap_cmd(cmd, NULL); chomp(top);
    if (!*top) die("crumb %s: not inside a git repository: %s", mode == 'c' ? "compile" : mode == 'v' ? "verify" : "status", root);
    c.top = top;
    reset_ignore(); load_ignore(top); policy_load(top);   /* D10: <root>/.crumbignore subtrees never participate */
    char *head = run_git(top, "rev-parse HEAD"); if (strlen(head) != 40) head = xstrdup("0000000000000000000000000000000000000000");
    if (head_out) strcpy(head_out, head);
    comp_load_files(&c);
    /* D4, D7: every directory holding a .crumb (tracked or freshly seeded on disk), deepest first */
    CDir *ds = NULL; size_t nd = 0, cap = 0; find_crumbs(top, "", &ds, &nd, &cap);
    { size_t tl; char *lz = NULL; snprintf(cmd, sizeof cmd, "git -C %s ls-files -z 2>/dev/null", rq); lz = cap_cmd(cmd, &tl);
      for (char *s = lz; s < lz + tl; s += strlen(s) + 1) {
        size_t l = strlen(s); const char *b = strrchr(s, '/'); b = b ? b + 1 : s;
        if (strcmp(b, ".crumb")) continue;
        char *d = l == 6 ? xstrdup(".") : xstrndup_(s, l - 7); int dup = 0;
        if (ignored_subtree(d)) { free(d); continue; }   /* D10 */
        for (size_t i = 0; i < nd; i++) if (!strcmp(ds[i].d, d)) dup = 1;
        if (dup) continue;
        if (nd == cap) { cap = cap ? cap * 2 : 32; ds = xrealloc(ds, cap * sizeof *ds); }
        ds[nd++].d = d;
      } }
    { size_t w = 0; for (size_t i = 0; i < nd; i++) {   /* sort -u */
        int dup = 0; for (size_t j = 0; j < w; j++) if (!strcmp(ds[j].d, ds[i].d)) dup = 1;
        if (!dup) ds[w++] = ds[i]; } nd = w; }
    for (size_t i = 0; i < nd; i++) { int n = 0; if (!strcmp(ds[i].d, ".")) n = -1; else for (const char *s = ds[i].d; *s; s++) if (*s == '/') n++; ds[i].depth = n; }
    qsort(ds, nd, sizeof *ds, cdcmp);
    int total = 0, changed = 0, stale = 0, found = 0; char stamp[21]; now_iso(stamp);
    int ondemand = mode == 'm' || root_on_demand(top);
    for (size_t i = 0; i < nd; i++) {
        const char *d = ds[i].d; char *cp = pjoin(d, ".crumb"), *full = pjoin(top, cp); struct stat sb;
        if (stat(full, &sb) || !S_ISREG(sb.st_mode)) continue;
        total++;
        char dg[65]; J *nw = comp_object(&c, d, dg); dig_set(&c, d, dg);
        if (mode == 'd') {   /* on demand: the block compile would have committed, with this HEAD as its stamp */
            if (g_digest_dir && !strcmp(d, g_digest_dir)) { jset(nw, "generated_at_commit", jstr(head)); jsort(nw); fputs(jdump(nw), stdout); found = 1; }
            continue;
        }
        char *txt = slurp(full); J *cr = txt ? jparse(txt) : NULL;
        if (ondemand) {   /* amendment 1: only the hand-written crumb is committed */
            J *x = cr && cr->t == JOBJ ? jget(cr, "extensions") : NULL;
            int has_gen = x && x->t == JOBJ && jget(x, "generated");
            int need_mark = mode == 'm' && !strcmp(d, ".") && !root_on_demand(top);
            if (!cr || cr->t != JOBJ) {
                stale++; if (!quiet) printf("INVALID    %s (not a JSON object)\n", d);
                if (mode == 'c' || mode == 'm') die("cannot compile %s: not a JSON object", cp);
                continue;
            }
            if (!has_gen && !need_mark) { if (mode == 's' && !quiet) printf("CURRENT    %s\n", d); continue; }
            if (mode == 's' || mode == 'v') { stale++; if (!quiet) printf("STALE      %s (committed generated data; run: crumb compile)\n", d); continue; }
            if (has_gen) { jdel(x, "generated"); if (x->n == 0) jdel(cr, "extensions"); }
            if (need_mark) { J *rx = jget(cr, "extensions"); if (!rx || rx->t != JOBJ) { rx = jnew(JOBJ); jset(cr, "extensions", rx); } jset(rx, GEN_POLICY_KEY, jstr(GEN_POLICY_ON_DEMAND)); }
            write_crumb(full, cr); changed++; if (!quiet) printf("STRIPPED   %s\n", d);
            continue;
        }
        J *old = jnew(JOBJ);
        if (cr && cr->t == JOBJ) { J *x = jget(cr, "extensions"), *g = x && x->t == JOBJ ? jget(x, "generated") : NULL;
            if (g && g->t == JOBJ) { old = jclone(g); jdel(old, "generated_at_commit"); jdel(old, "compiled_at"); } }
        jsort(old);
        strip_lc(old); J *nwc = jclone(nw); strip_lc(nwc);   /* D3a: last_commit is a stamp for staleness */
        char *ns = jcompact_s(nwc), *os = jcompact_s(old);
        if (!strcmp(ns, os)) { if (mode == 's' && !quiet) printf("CURRENT    %s\n", d); continue; }
        stale++;
        if (mode == 's') { if (!quiet) printf("%s %s\n", old->n == 0 ? "UNCOMPILED" : "STALE     ", d); }
        else if (mode == 'v') { if (!quiet) printf("STALE      %s\n", d); }
        else {
            if (!cr || cr->t != JOBJ) die("cannot compile %s: not a JSON object", cp);
            J *x = jget(cr, "extensions"); if (!x || x->t != JOBJ) { x = jnew(JOBJ); jset(cr, "extensions", x); }
            J *g = jclone(nw); jset(g, "generated_at_commit", jstr(head)); jset(g, "compiled_at", jstr(stamp));
            jset(x, "generated", g); jsort(cr);
            char *out = jdump(cr), *tmp = xmalloc(strlen(full) + 32); snprintf(tmp, strlen(full) + 32, "%s.tmp.%ld", full, (long)getpid());
            FILE *f = fcreate(tmp, 0); if (!f) die("cannot write %s", tmp);
            if (fputs(out, f) < 0 || fclose(f) != 0) die("write failed: %s", tmp);
            if (rename(tmp, full)) die("rename failed: %s", full);
            changed++; if (!quiet) printf("COMPILED   %s\n", d);
        }
    }
    if (total_out) *total_out = total;
    char h7[8]; memcpy(h7, head, 7); h7[7] = 0;
    const char *rd = dig_of(&c, "."); char rds[80]; snprintf(rds, sizeof rds, "sha256:%s", rd ? rd : "none");
    if (mode == 'd') { if (!found) die("crumb digest: %s holds no compiled .crumb", g_digest_dir ? g_digest_dir : "?"); return 0; }
    if (!quiet && ondemand) {   /* one line: verify.rs takes the first stdout line as the readiness note */
        if (mode == 'c') printf("crumb compile: %d crumbs, %d rewritten, HEAD %s, generated data on demand, root digest %s\n", total, changed, h7, rds);
        else if (mode == 'm') printf("crumb migrate: %d crumbs, %d rewritten, generated data is now derived on demand, root digest %s\n", total, changed, rds);
        else if (mode == 'v') {
            if (stale) printf("crumb verify: FAIL: %d of %d crumbs stale; run: crumb compile\n", stale, total);
            else printf("crumb verify: OK: %d crumbs current at HEAD %s, generated data on demand, root digest %s\n", total, h7, rds);
        } else printf("crumb status: %d crumbs, %d not current\n", total, stale);
        return stale;
    }
    if (!quiet) {
        if (mode == 'c') printf("crumb compile: %d crumbs, %d rewritten, HEAD %s\n", total, changed, h7);
        else if (mode == 'v') {
            if (stale) printf("crumb verify: FAIL: %d of %d crumbs stale; run: crumb compile\n", stale, total);
            else printf("crumb verify: OK: %d crumbs current\n", total);
        } else printf("crumb status: %d crumbs, %d not current\n", total, stale);
    }
    return stale;
}
static int cmd_compile(char mode, const char *root) { int t; int s = compile_engine(mode, root, 0, &t, NULL); return mode == 'v' && s ? 1 : 0; }
static int cmd_digest(const char *dir) {   /* amendment 1: print a directory's generated block, computed now */
    char r[PATH_MAX]; if (!realpath(dir, r)) die("no such directory: %s", dir);
    char *rq = shq(r), cmd[PATH_MAX + 80]; snprintf(cmd, sizeof cmd, "git -C %s rev-parse --show-toplevel 2>/dev/null", rq);
    char *top = cap_cmd(cmd, NULL); chomp(top);
    if (!*top) die("crumb digest: not inside a git repository: %s", dir);
    size_t tl = strlen(top); g_digest_dir = r[tl] ? xstrdup(r + tl + 1) : xstrdup(".");
    int t; compile_engine('d', top, 1, &t, NULL); return 0;
}
static int cmd_propose(const char *dir, const char *purpose) {   /* D5: only extensions.proposed, never .purpose */
    char *cp = pjoin(dir, ".crumb"), *txt = slurp(cp);
    if (!txt) die("no .crumb in %s", dir);
    J *cr = jparse(txt); if (!cr || cr->t != JOBJ) die("%s is not a JSON object", cp);
    J *x = jget(cr, "extensions"); if (!x || x->t != JOBJ) { x = jnew(JOBJ); jset(cr, "extensions", x); }
    const char *by = getenv("CRUMB_SESSION"); if (!by || !*by) by = getenv("USER"); if (!by) by = "";
    char at[21]; now_iso(at);
    J *pr = jnew(JOBJ); jset(pr, "purpose", jstr(purpose)); jset(pr, "status", jstr("PROPOSED")); jset(pr, "by", jstr(by)); jset(pr, "at", jstr(at));
    jset(x, "proposed", pr); jsort(cr);
    spit(cp, jdump(cr));
    printf("PROPOSED purpose for %s (stays PROPOSED until a human moves it into .purpose)\n", dir);
    return 0;
}

/* ---------- RFC-0003: crumb context ---------- */
#define CTX_TREE_MAX 40
static const char *crumb_purpose(J *c, char *buf, size_t n) {   /* .purpose, else PROPOSED, else none */
    const char *p = c ? jstrval(c, "purpose") : NULL;
    if (p && *p && !strstr(p, "not yet described")) { snprintf(buf, n, "%s", p); return buf; }
    J *x = c ? jget(c, "extensions") : NULL, *pr = x && x->t == JOBJ ? jget(x, "proposed") : NULL;
    const char *pp = pr && pr->t == JOBJ ? jstrval(pr, "purpose") : NULL;
    if (pp && *pp) { snprintf(buf, n, "PROPOSED: %s", pp); return buf; }
    snprintf(buf, n, "(no purpose yet)"); return buf;
}
static int cmd_context(const char *target) {
    char r[PATH_MAX];
    if (!realpath(target, r)) die("no such file or directory: %s", target);
    struct stat st; if (stat(r, &st)) die("cannot stat %s", target);
    char *abs = xstrdup(r), *dir = S_ISDIR(st.st_mode) ? xstrdup(r) : dir_of(r);
    Plane *p = plane_resolve(dir);
    if (!p) die("crumb context needs a git repository: %s", target);
    size_t tl = strlen(p->top); char *rel = abs[tl] ? xstrdup(abs + tl + 1) : xstrdup(".");
    int total = 0; char head[64] = "";
    int stale = compile_engine('s', p->top, 1, &total, head); head[7] = 0;
    printf("CRUMB CONTEXT %s\n", rel);
    if (stale) printf("Crumbs STALE: %d of %d (run crumb compile)\n", stale, total);
    else printf("Crumbs CURRENT at HEAD %s (%d crumbs)\n", head, total);
    printf("== TREE ==\n");
    { J *rc = load_crumb(p->top); char b[300]; if (rc) printf("  . : %s\n", crumb_purpose(rc, b, sizeof b)); }
    DIR *dp = opendir(p->top); char **nm = NULL; size_t nn = 0;
    if (dp) { struct dirent *e; while ((e = readdir(dp))) if (e->d_name[0] != '.') { nm = xrealloc(nm, (nn + 1) * sizeof *nm); nm[nn++] = xstrdup(e->d_name); } closedir(dp); }
    qsort(nm, nn, sizeof *nm, sstrcmp);
    size_t shown = 0, more = 0;
    for (size_t i = 0; i < nn; i++) {
        char *kd = pjoin(p->top, nm[i]); J *kc = load_crumb(kd);
        if (!kc) continue;
        if (shown >= CTX_TREE_MAX) { more++; continue; }
        char b[300]; printf("  %s/ : %s\n", nm[i], crumb_purpose(kc, b, sizeof b)); shown++;
    }
    if (more) printf("  ... %zu more\n", more);
    if (!shown) printf("  (no child crumbs)\n");
    printf("== YOUR TASK TOUCHES ==\n  %s%s\n", rel, S_ISDIR(st.st_mode) ? "/" : "");
    printf("== READ THESE CRUMBS (root to nearest) ==\n");
    { char **chain = NULL; size_t nc = 0, ptl = strlen(p->top); char *d = xstrdup(dir);
      for (;;) {
        size_t dl = strlen(d), tl2 = ptl;
        if (dl < tl2) break;
        if (load_crumb(d)) { chain = xrealloc(chain, (nc + 1) * sizeof *chain); chain[nc++] = xstrdup(d); }
        if (dl == tl2) break;
        char *up = dir_of(d); free(d); d = up;
      }
      if (!nc) printf("  (no .crumb at or above this path)\n");
      for (size_t i = nc; i-- > 0; ) { const char *rr = chain[i][ptl] ? chain[i] + ptl + 1 : "."; char b[300]; J *cj = load_crumb(chain[i]);
        printf("  %s%s.crumb : %s\n", !strcmp(rr, ".") ? "" : rr, !strcmp(rr, ".") ? "" : "/", crumb_purpose(cj, b, sizeof b)); }
    }
    printf("== CURRENT CONFLICTS ==\n");
    Txn *t = txn_begin(p, 0); txn_prune(t); int any = 0; size_t rl = strlen(rel);
    for (size_t i = 0; i < t->n; i++) if (!t->r[i]->agent) {
        J *lk = jget(t->r[i]->root, "locks");
        if (lk && lk->t == JOBJ) for (size_t k = 0; k < lk->n; k++) {
            const char *kk = lk->k[k]; size_t kl = strlen(kk);
            int hit = !strcmp(rel, ".") || !strcmp(kk, rel) || (kl > rl && !strncmp(kk, rel, rl) && kk[rl] == '/') || (rl > kl && !strncmp(rel, kk, kl) && rel[kl] == '/');
            if (hit) { print_lock(kk, lk->v[k]); any = 1; }
        }
    }
    if (!any) printf("  (none)\n");
    txn_end(t, 0);
    printf("== RELEVANT CONTINUATION ==\n");
    J *best = NULL; char *bestf = NULL; int nmatch = 0;
    { char **f = NULL; size_t n = 0; char *cd = pjoin(p->store, "continuations"); collect_json(cd, &f, &n);
      for (size_t i = 0; i < n; i++) {
        char *txt = read_bounded(f[i], MAX_RECORD_BYTES, NULL); J *c = txt ? jparse(txt) : NULL;
        if (g_enforce && (!c || c->t != JOBJ)) die("%s is not valid JSON; refusing (enforcement mode never skips unreadable state)", f[i]);
        if (!c || c->t != JOBJ || !jget(c, "identity") || !cont_matches(c, rel)) continue;
        nmatch++; if (!best || strcmp(cont_when(c), cont_when(best)) > 0) { best = c; bestf = f[i]; }
      } }
    if (!best) printf("  (none touches this path)\n");
    else {
        J *id = jget(best, "identity"), *s2 = jget(best, "state"), *items = s2 && s2->t == JOBJ ? jget(s2, "items") : s2;
        printf("  id: %s  sealed: %s  (%d matching, showing newest)\n  file: %s\n  reason: %s\n", sv(id, "checkpoint_id"), cont_when(best), nmatch, bestf, sv(id, "reason"));
        if (items && items->t == JARR) for (size_t i = 0; i < items->n && i < 8; i++) printf("  [%s] %s\n", sv(items->v[i], "tag"), sv(items->v[i], "claim"));
        if (items && items->t == JARR && items->n > 8) printf("  ... %zu more (crumb explain %s)\n", items->n - 8, rel);
    }
    return 0;
}

/* store-id [dir]: print the coordination store's id (the onboarding step: register it with git config crumb.storeId).
 * Registered: verified, never created. Unregistered (also under --strict, since this is how a store is registered):
 * the marker is created under the store lock if absent, exactly as synapse-coord `id` / ensure_store_id does. */
static int cmd_store_id(const char *dir) {
    Plane *p = plane_find(dir);
    if (!p) die("store-id needs a git repository: %s", dir);
    if (p->id.has_expect) ident_gate(&p->id, p->root, 0);
    else if (p->layout == 2) { p->id.warned = 1; int fd = root_lock(p->root, 1); ident_gate(&p->id, p->root, 1); close(fd); }
    else { p->id.warned = 1; Txn *t = txn_begin(p, 1); txn_end(t, 0); }
    char hex[33];
    if (!read_marker(p->root, hex)) die_x(EXIT_STORE_ID, "STORE_ID_MISSING: coordination store %s has no %s marker", p->root, STORE_ID_FILE);
    printf("%s\n", hex);
    if (!p->id.has_expect) fprintf(stderr, "crumb: coordination store %s is unregistered; register it: git config crumb.storeId %s\n", p->root, hex);
    return 0;
}
/* store-init [dir] (crumb924): make the coordination root a layout-2 (repository-namespaced) root, deliberately.
 * Under the root lock: STORE_ID as store-id does (registered: must match, never created); then LAYOUT is published
 * once (link(2), never replaced) and repos/ created. Refused while the root holds flat (layout 1) records, so old
 * locks are never silently dropped or reinterpreted. Idempotent on a layout-2 root. */
static int cmd_store_init(const char *dir) {
    Plane *p = plane_find(dir);
    if (!p) die("store-init needs a git repository: %s", dir);
    if (p->id.has_expect) ident_gate(&p->id, p->root, 0);
    mkdir_p(p->root);
    int fd = root_lock(p->root, 1);
    p->id.warned = 1; ident_gate(&p->id, p->root, 1);
    int created = 0;
    if (read_layout(p->root) != 2) {
        static const char *flat[] = { "dirs", "agents", "continuations", NULL };
        for (int i = 0; flat[i]; i++) {
            char *d = pjoin(p->root, flat[i]);
            if (count_json(d)) die("STORE_LAYOUT_V1_DATA: %s holds layout-1 records; refusing to make %s a layout-2 root (their locks would silently vanish): use a new empty root, or close every lease and move dirs/ agents/ continuations/ aside first", d, p->root);
            free(d);
        }
        static const char *empty[] = { "dirs", "agents", "continuations", "ledger", NULL };
        for (int i = 0; empty[i]; i++) { char *d = pjoin(p->root, empty[i]); rmdir(d); free(d); }   /* empty ones only */
        char *lp = pjoin(p->root, LAYOUT_FILE);
        publish_once(p->root, lp, LAYOUT_V2, strlen(LAYOUT_V2));
        free(lp); created = 1;
    }
    if (read_layout(p->root) != 2) die("store-init: %s did not become layout 2", p->root);
    char *rd = pjoin(p->root, "repos"); mkdir_p(rd); free(rd);
    close(fd);
    char hex[33];
    if (!read_marker(p->root, hex)) die_x(EXIT_STORE_ID, "STORE_ID_MISSING: coordination store %s has no %s marker", p->root, STORE_ID_FILE);
    if (!p->repo_id) p->repo_id = repo_id_resolve(p->abs, &p->repo_src);
    printf("STORE_INIT %s layout crumb-coord-layout/2 store %s%s\n", p->root, hex, created ? "" : " (already layout 2)");
    if (p->repo_id) printf("repository %s (from %s) -> %s/repos/%s\n", p->repo_id, p->repo_src, p->root, p->repo_id);
    else printf("repository (none resolved: set git config crumb.repoId <owner>/<repo> before using this root)\n");
    if (!p->id.has_expect) fprintf(stderr, "crumb: coordination store %s is unregistered; register it: git config crumb.storeId %s\n", p->root, hex);
    return 0;
}

static void usage(void) {
    fputs("usage: crumb [--strict] [--enforce] <command> ...\n"
          "  seed <root> [-n] [-v]                       write/refresh .crumb files (idempotent; -n dry run)\n"
          "  backfill <root> [--since <date>] [-n]       reconstruct history from git + lane reports (run after seed)\n"
          "  create <dir> <name> <purpose> [layer]       new .crumb for one directory\n"
          "  claim <agent> <dir> <target> <intent> [ttl] scent + advisory lock (exit 2 if held by another)\n"
          "  update <agent> <dir> <focus> [ttl]          refresh scent\n"
          "  whisper <from> <dir> <to|-> <msg> [prio] [target_file]\n"
          "  close <agent> <dir> <target> [action] [msg] release lock, add history vector, optional whisper\n"
          "  sniff <agent> <dir>                         what to read before touching a directory\n"
          "  explain <file-or-dir>                       nearest + inherited crumbs, coordination, commits, evidence, newest continuation\n"
          "  compile [root]                              RFC-0003: regenerate structural crumb data bottom-up (Merkle digests)\n"
          "  verify [root]                               exit 1 if any committed crumb differs from what compile would write\n"
          "  status [root]                               CURRENT / STALE / UNCOMPILED per crumb\n"
          "  migrate [root]                              RFC-0003 am. 1: strip committed generated data, mark the root on-demand\n"
          "  digest [dir]                                print the generated block of dir, computed from the tree now\n"
          "  propose <dir> <purpose>                     write extensions.proposed.purpose (never .purpose)\n"
          "  context [path]                              entry point: tree, what to read, conflicts, continuation, freshness\n"
          "  checkpoint <agent> [--reason R]             new Continuation Crumb (wraps cc.sh); then checkpoint --seal <id> [agent]\n"
          "  resume <id>                                 print record, revalidate against live repos (wraps cc.sh)\n"
          "  list [path]                                 live scents, locks, whispers under path\n"
          "  validate [path]                             check .crumb files against RFC-0001 required fields\n"
          "  store-id [dir]                              print the coordination store id (creates it if unregistered and absent)\n"
          "  store-init [dir]                            make the coordination root layout 2 (repos/<repo-id>/ namespaces), deliberately\n"
          "  check <agent> <dir> <target> [--generation N] [--key K]  read-only: exit 0 only if agent holds a valid lease on target or an ancestor\n"
          "store identity: expected id from CRUMB_EXPECT_STORE_ID, else git config crumb.storeId; --strict or\n"
          "  CRUMB_STRICT_STORE_ID=1 refuses unregistered stores. Exit 3 = store identity refusal, 4 = refused store file.\n"
          "repository id (layout 2): CRUMB_REPO_ID, else git config crumb.repoId, else origin URL <owner>/<repo>.\n"
          "enforcement (--enforce, CRUMB_ENFORCE=1, git config crumb.enforce true): registered store, layout 2, repo id,\n"
          "  verbatim agent ids, strict lease schema, no .crumb.local fallback, unreadable state is an error (exit 1).\n", stderr);
    exit(1);
}
static unsigned long long gen_arg(const char *s) { unsigned long long g; if (!u64_str(s, &g)) die("bad generation: %s (expected a decimal integer)", s); return g; }
int main(int argc, char **argv) {
    { const char *s = getenv("CRUMB_STRICT_STORE_ID"); if (s && !strcmp(s, "1")) g_strict = 1; }
    { const char *s = getenv("CRUMB_ENFORCE"); if (s && bool_word(s, "CRUMB_ENFORCE")) enforce_on(); }
    while (argc > 1 && (!strcmp(argv[1], "--strict") || !strcmp(argv[1], "--enforce"))) { if (!strcmp(argv[1], "--enforce")) enforce_on(); else g_strict = 1; argv++; argc--; }
    if (argc < 2) usage();
    const char *c = argv[1]; int a = argc - 2; char **v = argv + 2;
    if (!strcmp(c, "seed") && a >= 1) {
        int dry = 0, verb = 0;
        for (int i = 1; i < a; i++) { if (!strcmp(v[i], "-n")) dry = 1; else if (!strcmp(v[i], "-v")) verb = 1; else usage(); }
        return cmd_seed(v[0], dry, verb);
    }
    if (!strcmp(c, "backfill") && a >= 1) {
        const char *since = NULL; int dry = 0;
        for (int i = 1; i < a; i++) { if (!strcmp(v[i], "--since") && i + 1 < a) since = v[++i]; else if (!strcmp(v[i], "-n")) dry = 1; else usage(); }
        return cmd_backfill(v[0], since, dry);
    }
    if (!strcmp(c, "create") && a >= 3) return cmd_create(v[0], v[1], v[2], a > 3 ? v[3] : NULL);
    if (!strcmp(c, "claim") && a >= 4) return cmd_claim(v[0], v[1], v[2], v[3], ttl_arg(a > 4 ? v[4] : NULL, LOCK_TTL));
    if (!strcmp(c, "update") && a >= 3) return cmd_update(v[0], v[1], v[2], ttl_arg(a > 3 ? v[3] : NULL, SCENT_TTL));
    if (!strcmp(c, "whisper") && a >= 4) return cmd_whisper(v[0], v[1], v[2], v[3], a > 4 ? v[4] : NULL, a > 5 ? v[5] : NULL);
    if (!strcmp(c, "close") && a >= 3) return cmd_close(v[0], v[1], v[2], a > 3 ? v[3] : "modify", a > 4 ? v[4] : NULL);
    if (!strcmp(c, "sniff") && a >= 2) return cmd_sniff(v[0], v[1]);
    if (!strcmp(c, "explain") && a == 1) return cmd_explain(v[0]);
    if (!strcmp(c, "sha256") && a == 0) { Sha s; char h[65]; unsigned char t[8192]; size_t n; sha_init(&s); while ((n = fread(t, 1, sizeof t, stdin)) > 0) sha_add(&s, t, n); sha_hex(&s, h); printf("%s\n", h); return 0; }
    if (!strcmp(c, "compile") && a <= 1) return cmd_compile('c', a ? v[0] : ".");
    if (!strcmp(c, "verify") && a <= 1) return cmd_compile('v', a ? v[0] : ".");
    if (!strcmp(c, "status") && a <= 1) return cmd_compile('s', a ? v[0] : ".");
    if (!strcmp(c, "migrate") && a <= 1) return cmd_compile('m', a ? v[0] : ".");
    if (!strcmp(c, "digest") && a <= 1) return cmd_digest(a ? v[0] : ".");
    if (!strcmp(c, "propose") && a == 2) return cmd_propose(v[0], v[1]);
    if (!strcmp(c, "context") && a <= 1) return cmd_context(a ? v[0] : ".");
    if (!strcmp(c, "checkpoint")) return cmd_checkpoint(a, v);
    if (!strcmp(c, "resume") && a == 1) return cmd_resume(v[0]);
    if (!strcmp(c, "store-id") && a <= 1) return cmd_store_id(a ? v[0] : ".");
    if (!strcmp(c, "store-init") && a <= 1) return cmd_store_init(a ? v[0] : ".");
    if (!strcmp(c, "check") && a >= 3 && (a - 3) % 2 == 0 && a <= 7) {
        int has_want = 0; unsigned long long want = 0; const char *want_key = NULL;
        for (int i = 3; i < a; i += 2) {
            if (!strcmp(v[i], "--generation") && !has_want) { has_want = 1; want = gen_arg(v[i + 1]); }
            else if (!strcmp(v[i], "--key") && !want_key && *v[i + 1]) want_key = v[i + 1];
            else usage();
        }
        return cmd_check(v[0], v[1], v[2], has_want, want, want_key);
    }
    if (!strcmp(c, "list") || !strcmp(c, "validate")) {
        int val = !strcmp(c, "validate"); Tot t = {0, 0, 0};
        char *r = absdir(a ? v[0] : ".");
        Plane *sp = val ? NULL : plane_resolve(r);
        if (sp) g_skip_local = 1;
        walk_list(r, ".", 0, val, &t);
        if (sp) t.n_local += shared_list(sp);
        printf("%d .crumb file(s), %d directory(ies) with live local crumbs%s\n", t.n_crumb, t.n_local, val && t.bad ? ", INVALID found" : "");
        return t.bad ? 1 : 0;
    }
    usage();
    return 1;
}
