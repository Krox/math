module math.mat;

import std.traits;
import std.conv;
import std.math;
import std.complex;
import std.random;
import std.functional;
import std.format;
import std.algorithm;
import mir.ndslice;
import jive.array;


/**
 * Matrix/Vector of (small) fixed size.
 * Mainly intended for geometry in 2D,3D,4D.
 */
struct Mat(T, size_t N, size_t M)
{
	T[N*M] flat;

	enum Mat zero = Mat(0);
	enum Mat one = Mat(1);

	/** constructor for multiple of identity matrix */
	this(T v) pure
	{
		foreach(n; 0..N)
			foreach(m; 0..M)
				this[n,m] = n==m ? v : T(0);
	}

	/** constructor from given data */
	this(const(T)[] data) pure
	{
		assert(data.length == flat.length);
		flat[] = data[];
	}

	/** pseudo-constructor for random matrix */
	static Mat random()
	{
		Mat m;
		foreach(ref x; m.flat[])
			x = uniform(-1.0, 1.0);
		return m;
	}

	ContiguousSlice!(2, T) opSlice() pure
	{
		return flat[].sliced(N, M);
	}

	ContiguousSlice!(2, const(T)) opSlice() const pure
	{
		return flat[].sliced(N, M);
	}

	ContiguousSlice!(2, immutable(T)) opSlice() immutable pure
	{
		return flat[].sliced(N, M);
	}

	static if(N == 1 || M == 1) ref inout(T) opIndex(size_t i) inout pure
	{
		return flat[i];
	}

	ref T opIndex(size_t i, size_t j) pure
	{
		return opSlice()[i, j];
	}

	ref const(T) opIndex(size_t i, size_t j) const pure
	{
		return opSlice()[i, j];
	}

	ref immutable(T) opIndex(size_t i, size_t j) immutable pure
	{
		return opSlice()[i, j];
	}

	/** Mat +- Mat */
	Mat opBinary(string op)(Mat b) const pure
		if(op == "+" || op == "-")
	{
		Mat c;
		mixin("c.flat[] = this.flat[] "~op~" b.flat[];");
		return c;
	}

	/** Mat * / scalar */
	Mat opBinary(string op)(T b) const pure
		if(op == "*" || op == "/")
	{
		Mat c;
		mixin("c.flat[] = this.flat[] "~op~" b;");
		return c;
	}

	/** scalar *  Mat */
	Mat opBinaryRight(string op)(T b) const pure
		if(op == "*")
	{
		Mat c;
		c.flat[] = b * this.flat[];
		return c;
	}

	Mat!(T,N,K) opBinary(string op, size_t K)(Mat!(T,M,K) b) const pure
		if(op == "*")
	{
		auto r = Mat!(T,N,K).zero;
		foreach(n; 0..N)
			foreach(k; 0..K)
				foreach(m; 0..M)
					r[n,k] += this[n,m]*b[m,k];
		return r;
	}

	static if(N==M) Mat pow(long exp) const pure
	{
		assert(exp >= 0);
		Mat r = one;
		Mat base = this;

		while(exp)
		{
			if(exp & 1)
				r = r * base;
			exp >>= 1;
			base = base * base;
		}
		return r;
	}

	void opOpAssign(string op, S)(S b) pure
	{
		this = this.opBinary!op(b);
	}

	/** apply f on each entry */
	Mat cwise(alias f)() const
	{
		Mat r;
		foreach(i; 0..N*M)
			r.flat[i] = unaryFun!f(this.flat[i]);
		return r;
	}

	/** sum of entries */
	T sum() const pure
	{
		auto s = T(0);
		foreach(i; 0..N*M)
			s += this.flat[i];
		return s;
	}

	/** 2-norm */
	T abs() const pure
	{
		return sqrt(this.sqAbs);
	}

	/** square of 2-norm */
	T sqAbs() const pure
	{
		T s = T(0);
		foreach(i; 0..N*M)
			s += this.flat[i]*this.flat[i];
		return s;
	}

	/** pretty printing */
	string toString() const @property
	{
		string s;
		auto strings = slice!string(N, M);
		auto pitch = Array!size_t(M, 0);

		for(size_t i = 0; i < N; ++i)
			for(size_t j = 0; j < M; ++j)
			{
				import std.complex;
				static if(isFloatingPoint!T || is(T : Complex!R, R))
					strings[i,j] = format("%.3g", this[i,j]);
				else
					strings[i,j] = to!string(this[i,j]);
				pitch[j] = max(pitch[j], strings[i,j].length);
			}

		for(size_t i = 0; i < N; ++i)
		{
			if(i == 0)
				s ~= "⎛";
			else if(i == N-1)
				s ~= "⎝";
			else
				s ~= "⎜";


			for(size_t j = 0; j < M; ++j)
			{
				for(int k = 0; k < pitch[j]+1-strings[i,j].length; ++k)
					s ~= " ";
				s ~= strings[i,j];
			}

			if(i == 0)
				s ~= " ⎞\n";
			else if(i == N-1)
				s ~= " ⎠";
			else
				s ~= " ⎟\n";
		}
		return s;
	}
}

/** Inverse matrix. Implemented using direct formula */
Mat2!T inverse(T)(Mat2!T i) pure
{
	Mat2!T m;

	m[0,0] =  i[1,1];
	m[0,1] = -i[0,1];

	T det = i[0,0] * m[0,0] + i[1,0] * m[0,1];
	assert(det != 0.0, "cannot invert singular matrix");

	m[1,0] = -i[1,0];
	m[1,1] =  i[0,0];

	return m/det;
}

/** ditto */
Mat3!T inverse(T)(Mat3!T i) pure
{
	Mat3!T m;

	m[0,0] = i[1,1] * i[2,2] - i[2,1] * i[1,2];
	m[0,1] = i[2,1] * i[0,2] - i[0,1] * i[2,2];
	m[0,2] = i[0,1] * i[1,2] - i[1,1] * i[0,2];

	T det = i[0,0] * m[0,0] + i[1,0] * m[0,1] + i[2,0] * m[0,2];
	assert(det != 0.0, "cannot invert singular matrix");

	m[1,0] = i[2,0] * i[1,2] - i[1,0] * i[2,2];
	m[1,1] = i[0,0] * i[2,2] - i[2,0] * i[0,2];
	m[1,2] = i[1,0] * i[0,2] - i[0,0] * i[1,2];

	m[2,0] = i[1,0] * i[2,1] - i[1,1] * i[2,0];
	m[2,1] = i[0,1] * i[2,0] - i[0,0] * i[2,1];
	m[2,2] = i[0,0] * i[1,1] - i[0,1] * i[1,0];

	return m/det;
}

/** ditto */
Mat4!T inverse(T)(Mat4!T i) pure
{
	Mat4!T m;

	T d12 = (i[0,2] * i[1,3] - i[0,3] * i[1,2]);
	T d13 = (i[0,2] * i[2,3] - i[0,3] * i[2,2]);
	T d23 = (i[1,2] * i[2,3] - i[1,3] * i[2,2]);
	T d24 = (i[1,2] * i[3,3] - i[1,3] * i[3,2]);
	T d34 = (i[2,2] * i[3,3] - i[2,3] * i[3,2]);
	T d41 = (i[3,2] * i[0,3] - i[3,3] * i[0,2]);

	m[0,0] =  (i[1,1] * d34 - i[2,1] * d24 + i[3,1] * d23);
	m[0,1] = -(i[0,1] * d34 + i[2,1] * d41 + i[3,1] * d13);
	m[0,2] =  (i[0,1] * d24 + i[1,1] * d41 + i[3,1] * d12);
	m[0,3] = -(i[0,1] * d23 - i[1,1] * d13 + i[2,1] * d12);

	T det = i[0,0] * m[0,0] + i[1,0] * m[0,1] + i[2,0] * m[0,2] + i[3,0] * m[0,3];
	assert(det != 0.0, "cannot invert singular matrix");

	m[1,0] = -(i[1,0] * d34 - i[2,0] * d24 + i[3,0] * d23);
	m[1,1] =  (i[0,0] * d34 + i[2,0] * d41 + i[3,0] * d13);
	m[1,2] = -(i[0,0] * d24 + i[1,0] * d41 + i[3,0] * d12);
	m[1,3] =  (i[0,0] * d23 - i[1,0] * d13 + i[2,0] * d12);

	d12 = i[0,0] * i[1,1] - i[0,1] * i[1,0];
	d13 = i[0,0] * i[2,1] - i[0,1] * i[2,0];
	d23 = i[1,0] * i[2,1] - i[1,1] * i[2,0];
	d24 = i[1,0] * i[3,1] - i[1,1] * i[3,0];
	d34 = i[2,0] * i[3,1] - i[2,1] * i[3,0];
	d41 = i[3,0] * i[0,1] - i[3,1] * i[0,0];

	m[2,0] =  (i[1,3] * d34 - i[2,3] * d24 + i[3,3] * d23);
	m[2,1] = -(i[0,3] * d34 + i[2,3] * d41 + i[3,3] * d13);
	m[2,2] =  (i[0,3] * d24 + i[1,3] * d41 + i[3,3] * d12);
	m[2,3] = -(i[0,3] * d23 - i[1,3] * d13 + i[2,3] * d12);
	m[3,0] = -(i[1,2] * d34 - i[2,2] * d24 + i[3,2] * d23);
	m[3,1] =  (i[0,2] * d34 + i[2,2] * d41 + i[3,2] * d13);
	m[3,2] = -(i[0,2] * d24 + i[1,2] * d41 + i[3,2] * d12);
	m[3,3] =  (i[0,2] * d23 - i[1,2] * d13 + i[2,2] * d12);

	return m/det;
}

// convenience aliases
alias Vec(T, size_t N)  = Mat!(T, N, 1);
alias Vec2(T) = Vec!(T, 2);
alias Vec3(T) = Vec!(T, 3);
alias Vec4(T) = Vec!(T, 4);
alias Mat2(T) = Mat!(T, 2, 2);
alias Mat3(T) = Mat!(T, 3, 3);
alias Mat4(T) = Mat!(T, 4, 4);

// more aliases (naming following GLSL types)
alias vec2 = Vec2!float;
alias vec3 = Vec3!float;
alias vec4 = Vec4!float;
alias mat2 = Mat2!float;
alias mat3 = Mat3!float;
alias mat4 = Mat4!float;
alias dvec2 = Vec2!double;
alias dvec3 = Vec3!double;
alias dvec4 = Vec4!double;
alias dmat2 = Mat2!double;
alias dmat3 = Mat3!double;
alias dmat4 = Mat4!double;

pure @safe nothrow @nogc unittest
{
	import std.stdio;
	static immutable float[] data = [1,2,4,5,1,3,5,1,3,6,2,4,6,2,3,4];
	auto m = mat4(data);
	auto mi = inverse!float(m);
	assert((m*mi-mat4(1)).abs < 1e-6);
	assert((mi*m-mat4(1)).abs < 1e-6);
}
