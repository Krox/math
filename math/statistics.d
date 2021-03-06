module math.statistics;

private import std.math;
private import std.mathspecial;
private import std.random;
private import std.algorithm;
private import std.stdio;
private import std.format;
private import jive.array;

struct Histogram
{
	double low = 0, high = 0;
    int nBins = 0;

    Array!long hist;
    long count = 0;
    long countLow = 0;
    long countHigh = 0;
    double sum = 0;
    double sum2 = 0;
    double min = double.infinity;
    double max = -double.infinity;

    /** create empty histogram */
    this(double low, double high, int nBins)
    {
        this.low = low;
        this.high = high;
        this.nBins = nBins;
        hist.resize(nBins, 0);
    }

    /** create histogram from data with automatic binning */
    this(const(double)[] xs)
    {
        double a = double.infinity;
        double b = -double.infinity;

        foreach(x; xs)
        {
            a = std.algorithm.min(a, x);
            b = std.algorithm.max(b, x);
        }

        a -= 0.0001*(b-a);
        b += 0.0001*(b-a);

        this(a, b, std.algorithm.min(std.algorithm.max(cast(int)sqrt(cast(float)xs.length), 5), 200));

        foreach(x; xs)
            add(x);
    }

    void add(double x, long n = 1)
    {
        count += n;
        sum += n*x;
        sum2 += n*x*x;
        min = std.algorithm.min(min, x);
        max = std.algorithm.max(max, x);

        if(x < low)
            countLow += n;
        else if(x >= high)
            countHigh += n;
        else
            hist[cast(int)((x-low)/(high-low)*nBins)] += n;
    }

    double avg() const nothrow @property @safe
    {
        return sum / count;
    }

    double var() const nothrow @property @safe
    {
        return sum2/count - sum/count*sum/count;
    }

    /** iterate over center-of-bin / count-of-bin */
    int opApply(int delegate(double, double) dg) const
    {
        int r = 0;
        foreach(i, x; hist)
            if((r = dg(low + (i+0.5)*(high-low)/nBins, x)) != 0)
                break;
        return r;
    }

    void write() const
    {
        if(countLow)
            writefln("<:\t%s", countLow);
        foreach(x, y; this)
            writefln("%s:\t%s", x, y);
        if(countHigh)
            writefln(">:\t%s", countHigh);
        writefln("all:\t%s", count);
        writefln("avg = %s +- %s", avg, sqrt(var));
    }
}

/**
 * Estimate mean/variance/covariance of a population as samples are coming in.
 * This is the same as the standard formula "Var(x) = n/(n-1) (E(x^2) - E(x)^2)"
 * but numerically more stable.
 */
struct Estimator(size_t N = 1)
	if(N >= 2)
{
	@nogc: nothrow: pure: @safe:

	public double n = 0;
	private double[N] avg = [0]; // = 1/n ∑ x_i
	private double[N][N] sum2 = [[0]]; //= ∑ (x_i - meanX)*(y_i - meanY)

	/** add a new data point */
	void add(double[N] x...)
	{
		// TODO: figure out a way to do this statically
		if(n == 0)
		{
			foreach(ref a; avg)
				a = 0;
			foreach(ref l; sum2)
				l[] = 0;
		}

		n += 1;
		double[N] dx;
		for(int i = 0; i < N; ++i)
		{
			dx[i] = x[i] - avg[i];
			avg[i] += dx[i] / n;
		}

		for(int i = 0; i < N; ++i)
			for(int j = 0; j < N; ++j)
				sum2[i][j] += dx[i]*(x[j] - avg[j]);
	}

	/** mean in dimension i */
	Var mean(int i = 0) const
	{
		if(n < 2)
			return Var(avg[i], double.infinity);
		return Var(avg[i], var(i)/n);
	}

	/** variance in dimension i */
	double var(int i = 0) const
	{
		// NOTE: this is not the sample-variance, but an estimator of the population variance
		if(n < 2)
			return double.nan;
		return sum2[i][i]/(n-1);
	}

	/** covariane between dimensions i and j */
	double cov(int i = 0, int j = 1) const
	{
		if(n < 2)
			return double.nan;
		return sum2[i][j]/(n-1);
	}

	/** correlation coefficient between dimensions i and j */
	double corr(int i = 0, int j = 1) const
	{
		return cov(i,j)/sqrt(var(i)*var(j));
	}

	/** reset everything */
	void clear()
	{
		n = 0;
		avg[] = 0;
		foreach(ref s; sum2)
			s[] = 0;
	}
}

struct Estimator(size_t N = 1)
	if(N == 1)
{
	@nogc: nothrow: pure: @safe:

	public double n = 0;
	private double avg = 0;
	private double m2 = 0;
	private double m3 = 0;
	private double m4 = 0;

	this(const(double)[] xs)
	{
		foreach(x; xs)
			add(x);
	}

	/** add a new data point */
	void add(double x)
	{
		n += 1;
		double dx = x - avg;
		double dxn = dx/n;
		avg += dxn;
		m4 += dx*dxn*dxn*dxn*(n-1)*(n*n-3*n+3) + dxn*dxn*6*m2 - dxn*4*m3;
		m3 += dx*dxn*dxn*(n-1)*(n-2) - dxn*3*m2;
		m2 += dxn*dx*(n-1);
	}

	/** mean */
	Var mean() const @property
	{
		if(n < 2)
			return Var(avg, double.infinity);
		return Var(avg, var/n);
	}

	/** variance */
	double var() const @property
	{
		// NOTE: this is not the sample-variance, but an estimator of the population variance
		if(n < 2)
			return double.nan;
		return m2/(n-1);
	}

	/** skewness */
	double skew() const @property
	{
		return sqrt(n)*m3/pow(m2, 1.5);
	}

	/** excess kurtosis */
	double kurt() const @property
	{
		return n*m4/(m2*m2) - 3;
	}

	/** reset everything */
	void clear()
	{
		n = 0;
		avg = 0;
		m2 = 0;
		m3 = 0;
		m4 = 0;
	}
}

alias Average = Estimator!1;

/** analyze autocorrelation of a single stream of data */
struct Autocorrelation(size_t len = 20)
{
	private long count = 0;
	private double[len] history; // previously added values
	private Estimator!2[len] ac;

	this(const(double)[] xs)
	{
		foreach(x; xs)
			add(x);
	}

	/** add a new data point */
	void add(double x) pure
	{
		history[count % len] = x;
		for(int i = 0; i < min(count+1, len); ++i)
			ac[i].add(x, history[(count - i) % len]);
		count += 1;
	}

	Var mean() const pure
	{
		return ac[0].mean;
	}

	double var() const pure
	{
		return ac[0].var;
	}

	double cov(int lag = 1) const pure
	{
		return ac[lag].cov;
	}

	/** correlation between data[i] and data[i-lag] */
	double corr(int lag = 1) const pure
	{
		return ac[lag].corr;
	}

	/** print data to stdout */
	void write(size_t maxLen = len) const
	{
		for(int i = 0; i < maxLen; ++i)
			writefln("%s : %.2f", i, corr(i));
	}

	/** reset everything */
	void clear() pure
	{
		count = 0;
		foreach(ref a; ac)
			a.clear();
	}
}

/**
 * A (mean, variance) tuple. Can be interpreted as a random variable,
 * or a measurement with error. Standard arithmetic is overloaded to propagate
 * the error term, but there are severe limitations:
 *    -  but it assumes there is no correlation between variables,
 * so use carefully. For example "x+x" is not the same as "2*x" (and the latter
 * one is generally the correct one).
 */
struct Var
{
	double mean = double.nan;
	double var = 0;

	this(double mean, double var = 0) @nogc nothrow pure @safe
	{
		this.mean = mean;
		this.var = var;
	}

	/** standard deviation sqrt(variance) */
	double stddev() const @property @nogc nothrow pure @safe
	{
		return sqrt(var);
	}

	Var opBinary(string op)(double b) const @nogc nothrow pure @safe
	{
		switch(op)
		{
			case "+": return Var(mean + b, var);
			case "-": return Var(mean - b, var);
			case "*": return Var(mean*b, var*b*b);
			case "/": return Var(mean/b, var/(b*b));
			default: assert(false);
		}
	}

	Var opBinaryRight(string op)(double a) const @nogc nothrow pure @safe
	{
		switch(op)
		{
			case "+": return Var(a + mean, var);
			case "-": return Var(a - mean, var);
			case "*": return Var(a * mean, a*a*var);
			default: assert(false);
		}
	}

	Var opBinary(string op)(Var b) const @nogc nothrow pure @safe
	{
		switch(op)
		{
			case "+": return Var(mean + b.mean, var + b.var);
			case "-": return Var(mean - b.mean, var + b.var);
			case "*": return Var(mean * b.mean, mean*mean*b.var + b.mean*b.mean*var + var*b.var);
			default: assert(false);
		}
	}

	void opOpAssign(string op, S)(S b) @nogc nothrow pure @safe
	{
		this = this.opBinary!op(b);
	}

	/** returns human readable string "mean(error)" */
	void toString(scope void delegate(const(char)[]) sink, FormatSpec!char fmt) const
	{
		// special cases (not exhaustive actually)
		if(isNaN(mean))
			return sink("nan");
		if(isNaN(var) || var == 0)
			return formatValue(sink, mean, fmt);

		// scale to scientific notation
		double value = mean;
		double error = stddev;
		int e = 0;
		if(value != 0 && (fmt.spec == 'e' || fmt.spec == 's'))
			e = cast(int)log10(abs(value));
		value *= 10.0^^(-e);
		error *= 10.0^^(-e);

		// determine number of digits to print
		int prec = fmt.precision;
		if(prec == FormatSpec!char.UNSPECIFIED)
			prec = max(0, -cast(int)floor(log10(error))+1);

		// print it
		if(fmt.flPlus)
			formattedWrite(sink, "%+.*f", prec, value);
		else if(fmt.flSpace)
			formattedWrite(sink, "% .*f", prec, value);
		else
			formattedWrite(sink, "%.*f", prec, value);
		formattedWrite(sink, "(±%.*f)", prec, error);
		if(e != 0 || fmt.spec == 'e')
			formattedWrite(sink, "e%0+3s", e);
	}

	/** default formatting */
	string toString() const
	{
		return format("%s", this);
	}
}


//////////////////////////////////////////////////////////////////////
/// Model fitting
//////////////////////////////////////////////////////////////////////

/** fit the constant function f() = a */
struct ConstantFit
{
	Var a;
	double prob;

	this(const(Var)[] ys, double exact = double.nan) pure
	{
		long ndf;

		if(isNaN(exact))
		{
			// compute weighted mean
			a = Var(0,0);
			foreach(y; ys)
			{
				a.mean += y.mean/y.var;
				a.var += 1/y.var;
			}
			a.mean /= a.var;
			a.var = 1/a.var;
			ndf = ys.length-1;
		}
		else
		{
			a = Var(exact, 0);
			ndf = ys.length;
		}

		// compute chi^2 test
		double chi2 = 0;
		foreach(y; ys)
			chi2 += (y.mean-a.mean)^^2/y.var;
		prob = chi2cdf(ndf, chi2);
	}

	string toString() const
	{
		return format("%s (χ²-prob = %.2f)", a, prob);
	}
}

/** fit a linear function f(x) = ax + b using the Theil-Sen estimator */
struct RobustLinearFit
{
	double a, b;

	this(const(double)[] xs, const(double)[] ys)
	{
		assert(xs.length == ys.length);

		Array!double arr;

		if(xs.length <= 20)
		{
			// gather all slopes in O(n^2)
			for(size_t i = 0; i < xs.length; ++i)
				for(size_t j = i+1; j < xs.length; ++j)
				{
					double slope = (ys[i]-ys[j])/(xs[i]-xs[j]);
					if(!isNaN(slope)) // ignore case of duplicate x-coords
						arr.pushBack(slope);
				}
		}
		else
		{
			// gather a random sample of slopes in "O(600)"
			for(int k = 0; k < 600; ++k)
			{
				size_t i = uniform(0, xs.length);
				size_t j = uniform(0, xs.length);
				double slope = (ys[i]-ys[j])/(xs[i]-xs[j]);
				if(!isNaN(slope)) // ignore case of duplicate x-coords
					arr.pushBack(slope);
			}
		}

		if(arr.empty)
		{
			a = b = double.nan;
			return;
		}

		// determine a = median of slopes
		sort(arr[]);
		a = arr[$/2];

		// determine b = median of (y - ax)
		arr.clear();
		for(size_t i = 0; i < xs.length; ++i)
			arr.pushBack(ys[i] - a*xs[i]);
		sort(arr[]);
		b = arr[$/2];
	}
}

/** cumulative distribution function of chi-square distribution */
double chi2cdf(long ndf, double chi2) pure
{
	if(ndf <= 0 || isNaN(chi2))
		return double.nan;
	if(chi2 <= 0)
		return 0;
	return gammaIncomplete(0.5*ndf, 0.5*chi2);
}

//////////////////////////////////////////////////////////////////////
/// probability distributions to be used in monte-carlo algorithms
//////////////////////////////////////////////////////////////////////

// TODO: restructure this into transformations, possibly without parameters
// TODO: decide on weight-function outside support (error/undefined/zero)

/** uniform distribution in the interval [a,b) */
struct UniformDistribution
{
	double a = 0;
	double b = 1;

	this(double a, double b)
	{
		assert(a < b);
		this.a = a;
		this.b = b;
	}

	double sample() const
	{
		return a + uniform01()*(b-a);
	}

	double weight(double x) const
	{
		if(x < a || x >= b)
			return 0;
		return 1/(b-a);
	}
}

/** normal distribution with mean mu and deviation sigma */
struct NormalDistribution
{
	double mu = 0;
	double sigma = 1;
	double c = 1/sqrt(2*PI);

	this(double mu, double sigma)
	{
		assert(sigma > 0);
		this.mu = mu;
		this.sigma = sigma;
		this.c = 1/sqrt(2*PI)/sigma;
	}

	double sample() const
	{
        double u = uniform01();
        double v = uniform01();

        //double x = std.mathspecial.normalDistributionInverse(u);  // correct, but slow (?)
        double x = sqrt(-2*log1p(-u)) * sin(2*PI*v);
        //double y = sqrt(-2*log1p(-u)) * cos(2*PI*v);

        return mu + sigma * x;
	}

	double weight(double x) const
	{
		return c*exp(-(x*x)/(sigma*sigma)/2);
	}
}

/** exponential distribution with parameter lambda */
struct ExponentialDistribution
{
	double lambda = 1;

	this(double lambda)
	{
		assert(lambda > 0);
		this.lambda = lambda;
	}

	double sample() const
	{
		return -log1p(-uniform01())/lambda;
	}

	double weight(double x) const
	{
		if(x < 0)
			return 0;
		return lambda*exp(-lambda*x);
	}
}

/** uniform distribution from the hypercube [0,1)^N */
struct BoxDistribution(size_t N)
{
	Vec!(double, N) sample() const
	{
		Vec!(double, N) r;
		for(int i = 0; i < N; ++i)
			r[i] = uniform01();
		return r;
	}

	double weight(Vec!(double, N) x) const
	{
		return 1;
	}
}

/** uniform sampling from the standard N-simplex */
struct SimplexDistribution(size_t N)
{
  private ExponentialDistribution exp;

  Vec!(double, N) sample() const
  {
    Vec!(double, N) r;
    double s = exp.sample;
    for(int i = 0; i < N; ++i)
    {
      r[i] = exp.sample();
      s += r[i];
    }
    for(int i = 0; i < N; ++i)
      r[i] /= s;

    return r;
  }

  double weight(Vec!(double, N) x) const
  {
    double r = 1;
    for(int i = 2; i <= N; ++i)
      r *= i;
    return r;
  }
}

/**
 * Generator for pseudo-random vectors in [0,1]^d distributed proportional to
 * some function g which does not need to be normalized. The algorithm is quite
 * efficient, but (1) initial values can be bad and (2) successive values are
 * correlated. You can use the "burn" and "step" parameters to mitigate these
 * problems to some degree.
 */
struct Metropolis
{
	private double[] x; // current point
	private double[] x2; // temporary
	private double delegate(const(double)[]) g;
	private double gx; // = g(x)
	private size_t step;

	this() @disable;

	this(double delegate(const(double)[]) g, size_t dim, size_t burn = -1, size_t step = 1)
	{
		if(burn == -1)
			burn = 2*dim;
		assert(dim >= 1);
		assert(burn >= 0);
		assert(step >= 1);

		this.g = g;
		this.step = step;
		x = new double[dim];
		x2 = new double[dim];

		foreach(ref xi; x)
			xi = uniform01();
		gx = g(x);

		for(int i = 0; i < burn; ++i)
			next();
	}

	private void next()
	{
		// new proposal point
		x2[] = x[];
		size_t k = uniform(0, x.length);
		x2[k] = uniform01();

		// transition with some amplitude
		double gx2 = g(x2);
		double p = abs(gx2/gx);
		if(p >= 1 || uniform01() < p)
		{
			swap(x, x2);
			swap(gx, gx2);
		}
	}

	double weight() const pure @property
	{
		return gx;
	}

	const(double)[] front() const pure @property
	{
		return x;
	}

	void popFront()
	{
		for(int i = 0; i < step; ++i)
			next();
	}
}
