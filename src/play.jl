
"Play the given MIDI file using `fluidsynth`"
function play_synth(file::AbstractString)
    return run(`fluidsynth -qi $(soundfont) $(file)`)
end

"""
Record the given MIDI file and record it under `{ex}.wav` and `{ex}.mp3` using 
Fluisynth (MIDI -> WAV) and Lame (WAV -> MP3). 
"""
function record_synth(file::AbstractString, ex::AbstractString)
    wavfile = string(ex) * ".wav"
    err = @capture_err begin
        run(`fluidsynth -F $(wavfile) -qi $(soundfont) $(file)`, stdout, stderr)
        lame() do exe
            run(`$(exe) $(wavfile)`, stdout, stderr)
        end
    end
    if !isempty(err)
        @warn "Warning occurred during recording, you can find them in `record_synth.log`."
        write("record_synth.log", err)
    end
    return string(ex) * ".mp3"
end

function play_operation(code, duration, start_t::Real=0)
    note_ = hash_and_project(code, 5) + 3
    note = "C$(note_)"
    !iszero(start_t) && sleep(start_t)
    cmd = `play -qn synth $(duration) pluck $(note)`
    return cmd
end
