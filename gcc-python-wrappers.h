#ifndef INCLUDED__WRAPPERS_H
#define INCLUDED__WRAPPERS_H

#include "tree-pass.h"

PyMODINIT_FUNC initoptpass(void);

extern PyObject *
gcc_python_make_wrapper_tree(tree t);

extern PyObject *
gcc_python_make_wrapper_location(location_t loc);

extern PyObject *
gcc_python_make_wrapper_opt_pass(struct opt_pass *ptr);

PyObject *
gcc_Location_repr(struct PyGccLocation * self);

PyObject *
gcc_Location_str(struct PyGccLocation * self);


#endif /* INCLUDED__WRAPPERS_H */