
ZIPPLER_FILES = zippler/Archive.vala \
                zippler/Entry.vala \
                zippler/Utility.vala \
                zippler/Memory.vala

MINIZIP_C = minizip/ioapi.c \
            minizip/unzip.c \
            minizip/zip.c

MINIZIP_H = minizip/crypt.h \
            minizip/ioapi.h \
            minizip/unzip.h \
            minizip/zip.h
           
MINIZIP_O = ioapi.o unzip.o zip.o 

OBJECTS = Archive.vala.o \
          Entry.vala.o \
          Utility.vala.o \
          Memory.vala.o \
          $(MINIZIP_O)

all: libzippler.so libzippler.a
	
libzippler.so: linker_script $(MINIZIP_O)
	ld -shared -s -o libzippler.so `pkg-config --libs-only-L --libs-only-l glib-2.0 gobject-2.0 zlib` --version-script=linker_script -soname=libzippler.so $(OBJECTS)
	
linker_script: zippler.sym gen_linker_script.sh
	./gen_linker_script.sh libzippler.so zippler.sym linker_script
	
zippler.sym: $(ZIPPLER_FILES) $(MINIZIP_C) $(MINIZIP_H) vapi/minizip.vapi
	valac $(ZIPPLER_FILES) -X -Iminizip --library=zippler -X -fPIC --pkg minizip --vapidir=vapi --symbols=zippler.sym --vapi=zippler-1.0.vapi -H zippler.h -X -w -X -O2 -c
	
libzippler.a: linker_script $(MINIZIP_O) vapi/minizip.vapi zippler.sym
	ar rcs libzippler.a $(OBJECTS)
	
ioapi.o: minizip/ioapi.c minizip/ioapi.h
	cc -c minizip/ioapi.c -O2 -fPIC

unzip.o: minizip/unzip.c minizip/unzip.h
	cc -c minizip/unzip.c -O2 -fPIC

zip.o: minizip/zip.c minizip/zip.h
	cc -c minizip/zip.c -O2 -fPIC

ZipplerView: examples/ZipplerView.vala libzippler.so
	valac examples/ZipplerView.vala --pkg zippler-1.0 --pkg gtk+-3.0 --vapidir=. -X -I. -X -L. -X -lzippler -X -w
	
clean:
	rm -rf $(OBJECTS) libzippler.so libzippler.a zippler-1.0.vapi zippler.h zippler.sym linker_script
