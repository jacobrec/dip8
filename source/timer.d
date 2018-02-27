import std.stdio;

class Timer
{
    static long getCount()
    {
	asm
	{	naked	;
		rdtsc	;
		ret	;
	}
    }

    long starttime;

    this() { starttime = getCount(); }
    ~this()
    {
	writefln("elapsed time = %s", getCount() - starttime);
    }
}
