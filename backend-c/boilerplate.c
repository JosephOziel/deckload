#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define INIT_CAP 8

int num_allocs = 0;

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
        *cap *= 2;
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

void vec_drop(Vec s) {
    assert(*s.refcount);
    if(--*s.refcount) return;

    for(size_t i=0; i<s.len; ++i)
        if(s.mem[i].ty==BLOCK) vec_drop(s.mem[i].data.block);
    
    free_buf(s.mem);
    free_buf(s.refcount);
}

void vec_shallow_drop(Vec s) {
    assert(*s.refcount);
    if(--*s.refcount) return;
    
    free_buf(s.mem);
    free_buf(s.refcount);
}

void func_drop(Func f) {
    if(f.ty == BLOCK) vec_drop(f.data.block);
}

Func shallow_clone(Func f) {
    if(f.ty==BLOCK) *f.data.block.refcount+=1;
    return f;
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

Func vec_pop(Vec* v) {
    assert(v->len>0);
    return v->mem[--v->len];
}

void vec_dec_len(Vec* s, size_t d) {
    assert(s->len>=d);
    while(d--) func_drop(s->mem[--s->len]);
}

size_t vec_len(Vec s) {
    return s.len;
}

Func vec_last(Vec s, size_t idx) {
    assert(s.len>idx);

    return s.mem[s.len-idx-1];
}

Func vec_get(Vec s, size_t idx) {
    assert(s.len>=idx);

    return s.mem[idx];
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

void fb_drop(FrozenBlock fb) {
    vec_shallow_drop(fb.block);
}
// generated code begins...
