#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define INIT_CAP 8

int num_allocs = 0;

void error(char* s) {
    fprintf(stderr, "%s\n", s);
    exit(-1);
}

void* check_oom(void* p) {
    if(!p) error("out of memory");
    return p;
}

void* ensure(void* p, size_t len, size_t* cap, size_t size) {
    if(len > *cap) {
        while(len>*cap) *cap *= 2;
        return check_oom(realloc(p, *cap*size));
    }
    return p;
}

void* new_buf(size_t size) {
    num_allocs += 1;
    return check_oom(malloc(size));
}

void free_buf(void* ptr) {
    num_allocs -= 1;
    free(ptr);
}

struct Func;

typedef struct {
    struct Func* mem;
    size_t* refcount;
    size_t len;
    size_t cap;
} Vec ;

typedef struct Func(*F)(Vec*, size_t);

typedef enum {
    NONE = 0,
    FUNC = 1,
    BLOCK = 2
} Ty ;

typedef union {
    F func;
    Vec block;
} Data ;

typedef struct Func {
    Ty ty;
    Data data;
} Func ;

Func func_new(F f) {
    return (Func) { FUNC, (Data) { .func = f } };
}

Vec vec_new() {
    size_t* rc=new_buf(sizeof(size_t));
    *rc=1;
    return (Vec){
        .refcount=rc,
        .mem=new_buf(INIT_CAP*sizeof(Func)),
        .cap=INIT_CAP,
        .len=0
    };
}

void vec_shallow_drop(Vec s) {
    assert(*s.refcount);
    if(--*s.refcount) return;
    
    free_buf(s.mem);
    free_buf(s.refcount);
}

size_t vec_len(Vec s) {
    return s.len;
}

Func none() {
    return (Func) {
        .ty = NONE,
        .data = (Data) { .func = NULL }
    };
}

void vec_push(Vec* s, Func f) {
    s->mem=ensure(s->mem, s->len+1, &s->cap, sizeof(Func));
    s->mem[s->len++]=f;
}

Func vec_get(Vec s, size_t idx) {
    assert(s.len>=idx);

    return s.mem[idx];
}


Func shallow_clone(Func f) {
    if(f.ty==BLOCK) *f.data.block.refcount+=1;
    return f;
}

Func vec_pop(Vec* v) {
    assert(v->len>0);
    return v->mem[--v->len];
}

Func vec_last(Vec s, size_t idx) {
    assert(s.len>idx);

    return s.mem[s.len-idx-1];
}

void vec_append_except_last(Vec* v1, Vec v2) {
    v2.len--;
    v1->mem=ensure(v1->mem, v1->len+v2.len, &v1->cap, sizeof(Func));
    for(size_t i=0; i<v2.len; ++i) {
        v1->mem[i+v1->len]=shallow_clone(v2.mem[i]);
    }
    v1->len+=v2.len;
    v2.len++;
}

void vec_into_block(Vec* v, size_t len) {
    assert(v->len>=len);
    if (len==1) return;
    v->len-=len;
    Func* p = new_buf(len*sizeof(Func));
    memmove(p, v->mem+v->len, len*sizeof(Func));
    size_t* rc=new_buf(sizeof(size_t));
    *rc=1;
    vec_push(v, (Func) {
        .ty = BLOCK,
        .data = (Data) {
            .block = (Vec) { p, rc, len, len }
        }
    });
}

typedef struct {
    Vec block;
    size_t idx;
    size_t len;
} FrozenBlock;

FrozenBlock fb_new(Vec block) {
    return (FrozenBlock) {
        .block = block,
        .idx = 0,
        .len = vec_len(block)
    };
}

Func fb_advance(FrozenBlock* fb) {
    if(fb->idx>=fb->len) return none();
    return vec_get(fb->block, fb->idx++);
}

void fb_drop(FrozenBlock* fb) {
    vec_shallow_drop(fb->block);
}

typedef struct {
    FrozenBlock* mem;
    size_t len;
    size_t cap;
} TreeIter ;

TreeIter treeiter_new() {
    FrozenBlock* mem=new_buf(INIT_CAP*sizeof(FrozenBlock));
    return (TreeIter) {
        .mem=mem,
        .len=0,
        .cap=INIT_CAP,
    };
}

void treeiter_reset(TreeIter* ti, Func f) {
    Vec block=vec_new();
    vec_push(&block, f);
    ti->mem[0]=fb_new(block);
    ti->len=1;
}

Func treeiter_advance(TreeIter* ti, int(*enter)(Vec), void(*empty)(FrozenBlock*)) {
    Func f;
    FrozenBlock* block;

    while(ti->len--) {
        block=ti->mem+ti->len;
        f = fb_advance(block);

        if(f.ty) break;

        if(!ti->len) {
            fb_drop(block);
            return none();
        }

        (*empty)(block);
    }

    ti->len++;
    
    if(f.ty==BLOCK && (*enter)(f.data.block)) {
        ti->mem=ensure(ti->mem, ti->len+1, &ti->cap, sizeof(FrozenBlock));
        ti->mem[ti->len++]=fb_new(f.data.block);
    }

    return f;
}

void treeiter_drop(TreeIter ti) {
    free_buf(ti.mem);
}

TreeIter ti;

int drop_enter(Vec v) {
    assert(*v.refcount);
    int res=*v.refcount==1;
    if(!res) *v.refcount-=1;
    return res;
}

#ifdef drop_using_heap
void vec_drop(Vec s) {
    assert(*s.refcount);
    
    treeiter_reset(&ti, (Func){BLOCK, (Data){.block=s}});
    Func f;
    while((f=treeiter_advance(&ti, drop_enter, fb_drop)).ty) {}
}
#else
void vec_drop(Vec s) {
    assert(*s.refcount);
    if(--*s.refcount) return;

    for(size_t i=0; i<s.len; ++i)
        if(s.mem[i].ty==BLOCK) vec_drop(s.mem[i].data.block);
    
    free_buf(s.mem);
    free_buf(s.refcount);
}
#endif

void func_drop(Func f) {
    if(f.ty == BLOCK) vec_drop(f.data.block);
}

void vec_dec_len(Vec* s, size_t d) {
    assert(s->len>=d);
    while(d--) func_drop(s->mem[--s->len]);
}

void d_call(Func f, Vec* s, size_t arg_start, int var) {
    if(var && arg_start == vec_len(*s)) {
        vec_push(s, f);
        return;
    }

    Func t;
    while(f.ty) {
        t = f;
        if(f.ty == BLOCK) {
            vec_append_except_last(s, f.data.block);
            f=vec_last(f.data.block, 0);
        }
        assert(f.ty==FUNC);
        f=(*f.data.func)(s, arg_start);
        func_drop(t);
    }
}

int print_enter(Vec v) { printf("[ "); return 1; }
void print_end(FrozenBlock* b) { printf("] "); fb_drop(b); }

void print_func(F);

void print(Func f) {
    if(f.ty==FUNC) {
        print_func(f.data.func);
        return;
    }
    assert(f.ty==BLOCK);
    treeiter_reset(&ti, f);
    while((f=treeiter_advance(&ti, print_enter, print_end)).ty) {
        if(f.ty==FUNC) {
            print_func(f.data.func);
        }
    }
}

// generated code begins...
