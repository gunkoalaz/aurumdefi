import React, {Component} from 'react'
import Particles from 'react-tsparticles';

class ParticleSettings extends Component{
render(){
    return (
        <div>
            <Particles
                height='100vw' width='100vw'
                id='tsparticles'
                options={{
                    background: {
                        color: {value:"#2b2b2b"},
                    },
                    fpsLimit:60,
                    interactivity:{
                        detect_on: 'canvas',
                        modes: {
                            bubble: {
                                distance: 400,
                                duration: 2,
                                opacity: 0.8,
                                size: 100,
                            },
                            push: {
                                quantity:4,
                            },
                            repulse:{
                                distance: 200,
                                duration: 0.4,
                            },
                        },
                    },
                    particles:{
                        color: {value:"#dda74f"},
                        links: {
                            color: "#ffffff",
                            distance: 150,
                            enable: true,
                            opacity: 0.3,
                            width: 1,
                        },
                        collisions: {
                            enable: true,
                        },
                        move:{
                            direction: "none",
                            enable: true,
                            outMode: "bounce",
                            random: true,
                            speed: 3,
                            straight: false,
                        },
                        number: {
                            density: {
                                enable: true,
                                value_area: 400,
                            },
                            value: 10,

                        },
                    },
                    detectRetina: true,
                }}
            />
        </div>
    )}
}

export default ParticleSettings;