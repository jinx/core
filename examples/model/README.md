Jinx Model Example
===================

This directory contains a generic Jinx usage example which exercises most of the meta-data possibilities.
The associations are as follows:

* Parent is-a Person

* Child is-a Person

* 1 Parent : N Children (bidirectonal dependent)

* 1 Parent : 1 spouse Parent (bidirectonal independent)

* 1 Person : 1 Dependent (unidirectonal dependent)

* 1 Independent : N People  (bidirectional independent)

* M Children : N friend Children  (bidirectional self-referential typed independent)

* M Independents : N other Independents  (bidirectional self-referential untyped independent)

* 1-2 Parents : N Children (bidirectonal dependent)

Every object has an identifier and a name. Child has all supported primitive property types.
