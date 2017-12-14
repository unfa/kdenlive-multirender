# kdenlive-multirender
A Bash script enabling multi-threaded video rendering for Kdenlive.

## The problem
Rendering videos from Kdenlive doesn't saturate 100% of my CPU power. I want to render faster. Blender has scripts like Pulverize to handle this, but I couldn't find anythng for Kdenlive - so I programmed it myself.

## The solution

A solution to this is to render out multiplechunks of the project at once and concatenate them later. It's not the most memory or disk-efficient way, but it gets the job done faster, especially if you have lots of RAM and dozens of CPU cores to throw at the problem, and you don't want to wait 12 hours for your hourl-long FullHD video to render.

## How to use this tool

1. Create a Kdenlive render script
2. Copy __kdenlive-multirender.sh__ into the same directory
3. Run it:
      
      $ bash ./kdenlive-multirender.sh Kdenlive-render-script.sh 6

The script will use the original Kdenlive rendering script to create multiple other scripts and run them in parallel. Then it will use ffmpeg to concatenate the parial fiels into single vidoe file.The first parameter is the script filename, the second parameter is the amount of threads you want to use.

On my Ryzen 7 1700 machine with 16 GB of RAM, a complex 45-minute video saturates my CPU at 6 threads. YRMV - do not try using a ridiculous amount of threads unless you have a ridiculous amount of RAM, or you can fill your RAM and SWAP and just kill your system. Also note that disk I/O will become a bottleneck at some point, because each thread reads different data and writes different data.

## Final words
This is a quick-and dirty script, if you want to use it or improve it - feel free to do so, but don't blame me if it doens't work or it destroys your data. I made it, becasue I needed it and I wanted to share it with the world, becasue others might want it too.

Ultimately I hope this functionality will land in Kdenlive itself at some point.
