#ifndef __interface_h
#define __interface_h

#define TRUE 1
#define FALSE 0

extern uint triangulate_polygon(uint, uint *, double *[2], uint *[3], segment_t *, node_t *, trap_t *);
/* extern uint triangulate_polygon(uint, uint *, double (*)[2], uint (*)[3], segment_t *, node_t *, trap_t *); */
extern uint is_point_inside_polygon(double *, segment_t *, node_t *, trap_t *);

#endif /* __interface_h */
