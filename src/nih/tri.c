#include "triangulate.h"
#include <sys/time.h>
#include <string.h>


static uint initialise(uint n, segment_t *seg)
{
  uint i;

  for (i = 1; i <= n; i++)
    seg[i].is_inserted = FALSE; // redundant when used with read_segments;
  
  generate_random_ordering(n);
  
  return 0;
}

/* #ifdef STANDALONE */

uint main(uint argc, char *argv[], segment_t *seg, node_t *qs, trap_t *tr)
{
  uint n, nmonpoly, genus;
  uint op[SEGSIZE][3];
  uint i;
  uint ntriangles;

  /* if ((argc < 2) || ((n = read_segments(argv[1], &genus)) < 0)) */
  /*   { */
  /*     fprintf(stderr, "usage: triangulate <filename>\n"); */
  /*     exit(1); */
  /*   } */

  initialise(n, seg);
  construct_trapezoids(n, seg, qs, tr);
  nmonpoly = monotonate_trapezoids(n, seg, tr);
  ntriangles = triangulate_monotone_polygons(n, nmonpoly, op);
  
  for (i = 0; i < ntriangles; i++)
    printf("triangle #%d: %d %d %d\n", i,
	   op[i][0], op[i][1], op[i][2]);

  return 0;
}


/* #else  /\* Not standalone. Use this as an interface routine *\/ */


/* /\* Input specified as contours. */
/*  * Outer contour must be anti-clockwise. */
/*  * All inner contours must be clockwise. */
/*  *   */
/*  * Every contour is specified by giving all its points in order. No */
/*  * point shoud be repeated. i.e. if the outer contour is a square, */
/*  * only the four distinct endpoints shopudl be specified in order. */
/*  *   */
/*  * ncontours: #contours */
/*  * cntr: An array describing the number of points in each */
/*  *	 contour. Thus, cntr[i] = #points in the i'th contour. */
/*  * vertices: Input array of vertices. Vertices for each contour */
/*  *           immediately follow those for previous one. Array location */
/*  *           vertices[0] must NOT be used (i.e. i/p starts from */
/*  *           vertices[1] instead. The output triangles are */
/*  *	     specified  w.r.t. the indices of these vertices. */
/*  * triangles: Output array to hold triangles. */
/*  *   */
/*  * Enough space must be allocated for all the arrays before calling */
/*  * this routine */
/*  *\/ */


uint triangulate_polygon(uint ncontours, uint *cntr, double *vertices[2], uint *triangles[3], segment_t *seg, node_t *qs, trap_t *tr)
{
  uint i;
  uint nmonpoly, ccount, npoints, genus;
  uint n;

  memset((void *)seg, 0, sizeof(seg));
  ccount = 0;
  i = 1;
  
  while (ccount < ncontours)
    {
      int j;
      int first, last;

      npoints = cntr[ccount];
      first = i;
      last = first + npoints - 1;
      for (j = 0; j < npoints; j++, i++)
	{
	  seg[i].v0.x = vertices[i][0];
	  seg[i].v0.y = vertices[i][1];

	  if (i == last)
	    {
	      seg[i].next = first;
	      seg[i].prev = i-1;
	      seg[i-1].v1 = seg[i].v0;
	    }
	  else if (i == first)
	    {
	      seg[i].next = i+1;
	      seg[i].prev = last;
	      seg[last].v1 = seg[i].v0;
	    }
	  else
	    {
	      seg[i].prev = i-1;
	      seg[i].next = i+1;
	      seg[i-1].v1 = seg[i].v0;
	    }
	  
	  seg[i].is_inserted = FALSE;
	}
      
      ccount++;
    }
  
  genus = ncontours - 1;
  n = i-1;

  initialise(n, seg);
  construct_trapezoids(n, seg, qs, tr);
  nmonpoly = monotonate_trapezoids(n, seg, tr);
  triangulate_monotone_polygons(n, nmonpoly, triangles);
  
  return 0;
}


/* /\* This function returns TRUE or FALSE depending upon whether the  */
/*  * vertex is inside the polygon or not. The polygon must already have */
/*  * been triangulated before this routine is called. */
/*  * This routine will always detect all the points belonging to the  */
/*  * set (polygon-area - polygon-boundary). The return value for points  */
/*  * on the boundary is not consistent!!! */
/*  *\/ */

uint is_point_inside_polygon(double vertex[2], segment_t *seg, node_t *qs, trap_t *tr)
{
  point_t v;
  uint trnum, rseg;
  trap_t *t;

  v.x = vertex[0];
  v.y = vertex[1];
  
  trnum = locate_endpoint(&v, &v, 1, seg, qs);
  t = &tr[trnum];
  
  if (t->state == ST_INVALID)
    return FALSE;
  
  if ((t->lseg <= 0) || (t->rseg <= 0))
    return FALSE;
  rseg = t->rseg;
  return _greater_than_equal_to(&seg[rseg].v1, &seg[rseg].v0);
}


/* #endif /\* STANDALONE *\/ */
