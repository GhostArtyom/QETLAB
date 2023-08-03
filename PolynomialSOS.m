%%  POLYNOMIALSOS    Bounds the optimal value of a homogeneous polynomial on the unit sphere via the Sum-Of-Squares hierarchy
%   This function has four required arguments:
%     P: the polynomial to optimize, as a vector of its coefficients in
%        lexicographical order
%     N: the number of variables
%     D: half the degree of the polynomial
%     K: a non-negative integer that indicates the level of the hierarchy
%        used to bound the optimal value
%
%   OB = PolynomialSOS(P,N,D,K) is an upper bound on the maximum value of
%        the N-variable degree-D polynomial P. Higher values of K result
%        a better upper bound, at the expense of increased computational
%        cost.
%
%   This function has one optional argument:
%     OPTTYPE (optional, default 'max'): either 'max' or 'min', indicating
%        whether the polynomial should be maximized or minimized
%
%   [OB,IB] = PolynomialSOS(P,N,D,K,OPTTYPE) gives an outer bound (OB) and
%        an inner bound (IB) on the optimum value of the N-variable
%        degree-D polynomial P.
%
%   URL: http://www.qetlab.com/PolynomialSOS

%   author: Nathaniel Johnston (nathaniel@njohnston.ca)
%   package: QETLAB
%   last updated: August 3, 2023

function [ob,ib] = PolynomialSOS(p,n,d,k,varargin)
    % set optional argument defaults: OPTTYPE='max'
    [opttype] = opt_args({ 'max' },varargin{:});
    do_max = strcmpi(opttype,'max');% true means maximize, false means minimize

    ob_start = tic;
    M = PolynomialAsMatrix(p,n,d,k);
    s = length(M);

    P = SymmetricProjection(n,d+k,1,0);
    cvx_begin sdp quiet
        cvx_precision best;
        variable rho(s,s) hermitian
        if(do_max)
            maximize real(trace(rho*M))
        else
            minimize real(trace(rho*M))
        end
        subject to
            rho >= 0;
            trace(rho) == 1;
            PartialTranspose(P*rho*P',1,n*ones(1,d+k)) == P*rho*P';
    cvx_end
    ob = real(cvx_optval);
    ob_end = toc(ob_start);% time spent performing outer bound calculation

    % If requested, compute inner bounds via error bounds.
    if(nargout > 1)
        ib_start = tic;
        ib_end = 0;
        if(k > 0)% error estimate is based on the k = 0 matrix
            M = PolynomialAsMatrix(p,n,d);
        end

        if(do_max)
            ib = ob - 4*d*(n-1)*norm(full(M))/(d+k+1);
        else
            ib = ob + 4*d*(n-1)*norm(full(M))/(d+k+1);
        end

        si = symind(2*d,1:n);
        ob_end = ob_end / 4;
        while(ib_end < ob_end)% keep computing randomized inner bounds until we have spent at least 25% as much time on this as we did on outer bounds
            new_ib = poly_rand_input(p,n,si);
            if(do_max)
                ib = max(ib,new_ib);
            else
                ib = min(ib,new_ib);
            end
            ib_end = toc(ib_start);
        end
    end
end