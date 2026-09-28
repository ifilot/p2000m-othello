# Othello for the Philips P2000M: C (Z88DK), CP/M target.
#
# The compiler runs in the z88dk/z88dk Docker image. `make test` needs only a
# host C++ compiler. `make run` needs sibling checkouts of p2000m-cpm (SD
# kernel, cartridge and image tool) and p2000m-emulator (graphical emulator).

IMAGE    ?= z88dk/z88dk
DOCKER_ENV = $(if $(SOURCE_DATE_EPOCH),-e SOURCE_DATE_EPOCH=$(SOURCE_DATE_EPOCH),)
ZCC      = docker run --rm --user $(shell id -u):$(shell id -g) $(DOCKER_ENV) \
           -v "$(CURDIR)":/src -w /src $(IMAGE) zcc

SOURCES  = src/othello.c src/game.c src/cpu.c
HEADERS  = src/game.h src/cpu.h src/version.h
COM      = build/OTHELLO.COM
RULES_TEST = build/othello-game-test

CPM      ?= ../p2000m-cpm
EMULATOR ?= ../p2000m-emulator
RUN_IMAGE = build/othello-run.img

.PHONY: all build test run clean

all: build

build: $(COM)

$(COM): $(SOURCES) $(HEADERS) Makefile
	mkdir -p build
	$(ZCC) +cpm -create-app -o $(COM) $(SOURCES)

# Property tests of the platform-neutral rules engine and CPU player.
test: $(RULES_TEST)
	$(RULES_TEST)

$(RULES_TEST): tests/othello_game.cpp src/game.c src/cpu.c src/game.h src/cpu.h
	mkdir -p build
	g++ -std=c++17 -O2 -Isrc tests/othello_game.cpp src/game.c src/cpu.c -o $@

# Open the game in the graphical emulator on a disposable SD image (J: GAMES).
run: build
	@test -f $(CPM)/build/cartridge.bin -a -f $(CPM)/build/kernel.bin || \
		(cd $(CPM) && python3 tools/build.py)
	cmake --build $(EMULATOR)/build --target p2000m -j2
	rm -f $(RUN_IMAGE)
	python3 $(CPM)/tools/sd_image.py $(RUN_IMAGE) \
		--kernel $(CPM)/build/kernel.bin --drive J $(COM)
	$(EMULATOR)/build/p2000m --cartridge $(CPM)/build/cartridge.bin \
		--sd-card $(RUN_IMAGE) --co-board --run J:OTHELLO

clean:
	rm -rf build
