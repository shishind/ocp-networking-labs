import clsx from 'clsx';
import Link from '@docusaurus/Link';
import useDocusaurusContext from '@docusaurus/useDocusaurusContext';
import Layout from '@theme/Layout';
import Heading from '@theme/Heading';

import styles from './index.module.css';

function HomepageHeader() {
  const {siteConfig} = useDocusaurusContext();
  return (
    <header className={clsx('hero hero--primary', styles.heroBanner)}>
      <div className="container" style={{position: 'relative', zIndex: 1}}>
        <Heading as="h1" className="hero__title" style={{fontSize: '3.5rem', fontWeight: '800', color: 'white', textShadow: '0 2px 10px rgba(0,0,0,0.2)'}}>
          {siteConfig.title}
        </Heading>
        <p className="hero__subtitle" style={{fontSize: '1.5rem', color: 'rgba(255,255,255,0.95)', fontWeight: '500'}}>{siteConfig.tagline}</p>
        <p className={styles.heroDescription}>
          Choose your starting point based on your knowledge level
        </p>
        <div style={{marginTop: '2rem'}}>
          <Link
            className="button button--secondary button--lg"
            to="/intro"
            style={{
              backgroundColor: 'white',
              color: '#667eea',
              fontWeight: '700',
              fontSize: '1.1rem',
              padding: '0.75rem 2rem',
              boxShadow: '0 4px 14px rgba(0,0,0,0.2)'
            }}>
            Explore All Labs →
          </Link>
        </div>
      </div>
    </header>
  );
}

function StartingPoints() {
  const startingOptions = [
    {
      emoji: '🌱',
      title: 'Complete Beginner',
      subtitle: 'Start at Week 1',
      description: 'New to networking? Start from the basics.',
      topics: 'OSI Model, IP, DNS, TCP/UDP, Routing',
      link: '/week1-2/D1_OSI_Model',
      buttonText: 'Start Week 1',
      color: '#10a37f',
    },
    {
      emoji: '🐧',
      title: 'Know Networking',
      subtitle: 'Start at Week 3',
      description: 'Understand IP/DNS? Learn containers.',
      topics: 'Namespaces, veth, bridges, Docker',
      link: '/week3-4/D15_Network_Namespaces',
      buttonText: 'Start Week 3',
      color: '#0070f3',
    },
    {
      emoji: '☸️',
      title: 'Know Containers',
      subtitle: 'Start at Week 5',
      description: 'Understand Docker? Learn Kubernetes.',
      topics: 'Services, CoreDNS, NetworkPolicy, CNI',
      link: '/week5-6/D29_kind_Setup',
      buttonText: 'Start Week 5',
      color: '#326ce5',
    },
    {
      emoji: '🔴',
      title: 'Know Kubernetes',
      subtitle: 'Start at Week 7',
      description: 'Understand K8s? Master OpenShift.',
      topics: 'OVS, OVN, Routes, 4 Traffic Flows',
      link: '/week7/D43_OVS_Fundamentals',
      buttonText: 'Start Week 7',
      color: '#cc0000',
    },
  ];

  return (
    <section className={styles.startingPoints}>
      <div className="container">
        <Heading as="h2" className="text--center margin-bottom--lg" style={{
          fontSize: '2.5rem',
          fontWeight: '800',
          background: 'linear-gradient(135deg, #667eea 0%, #764ba2 100%)',
          WebkitBackgroundClip: 'text',
          WebkitTextFillColor: 'transparent',
          backgroundClip: 'text'
        }}>
          Choose Your Starting Point
        </Heading>
        <p className="text--center margin-bottom--xl" style={{fontSize: '1.2rem', color: '#5a5a5a', maxWidth: '800px', margin: '0 auto 3rem', lineHeight: '1.8'}}>
          Not everyone needs to start from scratch. Pick the week that matches your current knowledge level and jump right in!
        </p>
        <div className="row">
          {startingOptions.map((option, idx) => (
            <div key={idx} className="col col--3">
              <div className={clsx('card', styles.startingCard)}>
                <div className="card__header text--center">
                  <div className={styles.startingEmoji}>{option.emoji}</div>
                  <Heading as="h3">{option.title}</Heading>
                  <p><strong>{option.subtitle}</strong></p>
                </div>
                <div className="card__body">
                  <p>{option.description}</p>
                  <p className={styles.topics}><small>{option.topics}</small></p>
                </div>
                <div className="card__footer">
                  <Link
                    className="button button--primary button--block"
                    to={option.link}
                    style={{backgroundColor: option.color}}>
                    {option.buttonText} →
                  </Link>
                </div>
              </div>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}

function Features() {
  return (
    <section className={styles.features}>
      <div className="container">
        <Heading as="h2" className="text--center margin-bottom--xl" style={{
          fontSize: '2.5rem',
          fontWeight: '800',
          color: '#2c3e50'
        }}>
          What You'll Get
        </Heading>
        <div className="row">
          <div className="col col--4 text--center">
            <div className={styles.featureIcon}>🎯</div>
            <Heading as="h3" style={{fontSize: '1.5rem', marginBottom: '1rem'}}>49 Hands-On Labs</Heading>
            <p style={{fontSize: '1.05rem', color: '#5a5a5a', lineHeight: '1.7'}}>Practical exercises covering 7 weeks from basics to advanced OCP troubleshooting.</p>
          </div>
          <div className="col col--4 text--center">
            <div className={styles.featureIcon}>💻</div>
            <Heading as="h3" style={{fontSize: '1.5rem', marginBottom: '1rem'}}>268+ Exercises</Heading>
            <p style={{fontSize: '1.05rem', color: '#5a5a5a', lineHeight: '1.7'}}>Real commands, real scenarios. Type every command yourself and learn by doing.</p>
          </div>
          <div className="col col--4 text--center">
            <div className={styles.featureIcon}>📚</div>
            <Heading as="h3" style={{fontSize: '1.5rem', marginBottom: '1rem'}}>880+ Commands</Heading>
            <p style={{fontSize: '1.05rem', color: '#5a5a5a', lineHeight: '1.7'}}>Comprehensive cheat sheets for daily OCP network troubleshooting.</p>
          </div>
        </div>
      </div>
    </section>
  );
}

function QuickLinks() {
  return (
    <section className={styles.quickLinks}>
      <div className="container">
        <Heading as="h2" className="text--center margin-bottom--lg" style={{
          fontSize: '2.5rem',
          fontWeight: '800',
          background: 'linear-gradient(135deg, #667eea 0%, #764ba2 100%)',
          WebkitBackgroundClip: 'text',
          WebkitTextFillColor: 'transparent',
          backgroundClip: 'text'
        }}>
          Quick Access
        </Heading>
        <p className="text--center margin-bottom--xl" style={{fontSize: '1.1rem', color: '#5a5a5a', maxWidth: '700px', margin: '0 auto 3rem'}}>
          Jump straight to what you need
        </p>
        <div className="row">
          <div className="col col--6">
            <div className="card">
              <div className="card__header">
                <Heading as="h3">📋 Cheat Sheets</Heading>
              </div>
              <div className="card__body">
                <ul>
                  <li><Link to="/cheat-sheets/Master_Commands_QuickRef">Master Commands (All Phases)</Link></li>
                  <li><Link to="/cheat-sheets/Phase1_Core_Networking_CheatSheet">Core Networking Commands</Link></li>
                  <li><Link to="/cheat-sheets/Phase4_OpenShift_CheatSheet">OpenShift Commands</Link></li>
                </ul>
              </div>
            </div>
          </div>
          <div className="col col--6">
            <div className="card">
              <div className="card__header">
                <Heading as="h3">🚀 Get Started</Heading>
              </div>
              <div className="card__body">
                <p><strong>Clone the repository:</strong></p>
                <pre style={{fontSize: '0.9rem'}}>
                  git clone https://github.com/shishind/ocp-networking-labs.git
                </pre>
                <p className="margin-top--md">
                  <Link to="https://github.com/shishind/ocp-networking-labs" className="button button--secondary button--block">
                    View on GitHub →
                  </Link>
                </p>
              </div>
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}

function Stats() {
  const stats = [
    { icon: '📅', value: '7', label: 'Weeks of Content' },
    { icon: '📝', value: '49', label: 'Lab Modules' },
    { icon: '⚡', value: '268+', label: 'Hands-On Exercises' },
    { icon: '🎓', value: '880+', label: 'Commands to Master' },
  ];

  return (
    <section style={{
      padding: '3rem 0',
      background: 'linear-gradient(135deg, #667eea 0%, #764ba2 100%)',
      color: 'white'
    }}>
      <div className="container">
        <div className="row">
          {stats.map((stat, idx) => (
            <div key={idx} className="col col--3 text--center" style={{padding: '1rem'}}>
              <div style={{
                fontSize: '3rem',
                marginBottom: '0.5rem',
                filter: 'drop-shadow(0 2px 4px rgba(0,0,0,0.2))'
              }}>
                {stat.icon}
              </div>
              <div style={{
                fontSize: '2.5rem',
                fontWeight: '800',
                marginBottom: '0.25rem',
                textShadow: '0 2px 4px rgba(0,0,0,0.2)'
              }}>
                {stat.value}
              </div>
              <div style={{
                fontSize: '1.1rem',
                opacity: 0.95,
                fontWeight: '500'
              }}>
                {stat.label}
              </div>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}

export default function Home(): JSX.Element {
  const {siteConfig} = useDocusaurusContext();
  return (
    <Layout
      title={`${siteConfig.title}`}
      description="Complete 7-week hands-on curriculum for OpenShift networking troubleshooting">
      <HomepageHeader />
      <main>
        <StartingPoints />
        <Stats />
        <Features />
        <QuickLinks />
      </main>
    </Layout>
  );
}
