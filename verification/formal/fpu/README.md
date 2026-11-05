# Core-facing FPU formal environment

The proof checks adapter reset, one-request-at-a-time admission, output holding
under backpressure, completion retirement, and exact simple-operation capture.
The separately proved `fpu_datapath` is replaced by an inactive contract stub
so this suite isolates the adapter's simple-operation control path.
