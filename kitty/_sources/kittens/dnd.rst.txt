Drag and Drop
==================================================

.. only:: man

    Overview
    --------------

    *Drag and drop of files from the shell*

.. highlight:: sh


The ``dnd`` kitten can be used to drag and drop files between
the shell and arbitrary GUI programs, it even works over SSH, so you
can easily and seamlessly transfer files from one computer to another,
simply by dragging from one kitty window to another.
Using it is as simple as::

    kitten dnd file-to-drag.xyz

Then, start dragging with the mouse inside the window, and :file:`file-to-drag.xyz`
will be dragged and you can drop it onto a GUI file manager or another window
running this kitten. You can specify directories as well to drag entire trees.

Similarly, dropping works by running the kitten::

    kitten dnd

Then, drag some files from a GUI file manager or another window running the dnd kitten
and drop them onto this window. The files will be copied or moved (depending on
which area you drop them) into the current working directory.

The best part is this works even over SSH. So if you just want to quickly
transfer some files from one computer to another all you need to so is ssh into
the remote computer::

    kitten ssh remote-computer-name

Then, run the dnd kitten on the remote computer::

    kitten dnd files-or-dirs-to-drag

That's it, you can now drag form or drop to the remote computer. See below for
customising the behavior of the kitten via command line flags.

This kitten uses a new protocol developed by kitty to function, for details,
see :doc:`/dnd-protocol`.

.. program:: kitty +kitten dnd


.. include:: /generated/cli-kitten-dnd.rst
