import std.concurrency: Tid;

// Can't use core.sync.mutex due to the member functions not being `scope`
static struct MutexImpl {

    import core.sys.posix.pthread;

    private pthread_mutex_t _mutex;

    @disable this();

    this(pthread_mutexattr_t* attr) @trusted shared scope {
        pthread_mutex_init(cast(pthread_mutex_t*)&_mutex, attr);
    }

    ~this() @trusted scope {
        pthread_mutex_destroy(cast(pthread_mutex_t*)&_mutex);
    }

    void lock_nothrow() shared scope nothrow {
        pthread_mutex_lock(cast(pthread_mutex_t*)&_mutex);
    }

    void unlock_nothrow() shared scope nothrow {
        pthread_mutex_unlock(cast(pthread_mutex_t*)&_mutex);
    }
}

struct Mutex(T) {

    // Can't use core.sync.mutex due to the member functions not being `scope`
    //import core.sync.mutex: MutexImpl = Mutex;

    private shared T _payload;
    private shared MutexImpl _mutex;

    this(A...)(auto ref A args) shared {
        import std.functional: forward;

        //this._mutex = new shared MutexImpl();
        this._mutex = shared MutexImpl(null /*attr*/);
        this._payload = T(forward!args);
    }

    static struct Guard {

        private shared T* _payload;
        private shared MutexImpl* _mutex;

        alias payload this;

        scope T* payload() @trusted {
            return cast(T*)_payload;
        }

        ~this() scope @trusted  {
            _mutex.unlock_nothrow();
        }
    }

    auto lock() shared @trusted {
        _mutex.lock_nothrow;
        return Guard(&_payload, &_mutex);
    }
}


void main() @safe {
    import std.stdio;
    import std.concurrency: spawn, send, receiveOnly, thisTid;

    auto s = shared Mutex!int(42);

    {
        scope i = s.lock();
        *i = 33;
        () @trusted { writeln("i: ", *i); }();
    }

    auto tid = () @trusted { return spawn(&func, thisTid); }();
    () @trusted { tid.send(&s); }();
    () @trusted { receiveOnly!bool; }();
    () @trusted { writeln("i is now ", *s.lock); }();
}


void func(Tid tid) @trusted {
    import std.concurrency: receive, send;

    receive(
        (shared(Mutex!int)* m) {
            auto i = m.lock;
            *i = ++*i;
        },
    );

    tid.send(true);
}
